#!/bin/bash

# Configuration
STRESS_DURATION=60  # Hardcoded stress duration of 60 seconds
TEST_RUNS="${1:-5}"  # Number of test runs, default is 5
STATS_INTERVAL=1    # Interval in seconds to collect stats
CPU_CORES=8         # Number of CPU cores to stress

# Get the MinIO container ID (suppressing the output)
CONTAINER_ID=$(docker ps -qf "name=minio$" 2>/dev/null)

if [ -z "$CONTAINER_ID" ]; then
  echo "Error: MinIO container is not running."
  exit 1
fi

# Function to parse vm_stat output and convert pages to MB
get_memory_usage() {
  vm_stat | awk '
    /Pages active/ { active=$3 }
    /Pages inactive/ { inactive=$3 }
    /Pages speculative/ { speculative=$3 }
    /Pages free/ { free=$3 }
    /Pages wired down/ { wired=$4 }
    /Pages occupied by compressor/ { compressor=$5 }
    END {
      active=active*4096/1024/1024
      inactive=inactive*4096/1024/1024
      speculative=speculative*4096/1024/1024
      free=free*4096/1024/1024
      wired=wired*4096/1024/1024
      compressor=compressor*4096/1024/1024
      used=active+inactive+speculative+wired+compressor
      available=free+inactive+speculative
      printf "%.2f %.2f %.2f\n", used, free, available
    }'
}

# Function to perform a stress test and collect system stats
perform_stress_test() {
  echo "Running test $1/$TEST_RUNS..."
  echo "Stressing CPU for ${STRESS_DURATION} seconds..."

  # Start CPU stress (suppressing the output)
  for _ in $(seq 1 $CPU_CORES); do
    docker exec -d $CONTAINER_ID sh -c "yes > /dev/null & echo \$! >> /tmp/yes_pids" 2>/dev/null
  done

  # Collect system load, IO stats, and memory usage
  echo "Collecting system stats..."
  (
    for _ in $(seq 1 $((STRESS_DURATION / STATS_INTERVAL))); do
      # Capture load average
      uptime | awk '{print $10}' >> "load_avg_test_$1.txt"
      # Capture IO stats
      iostat -d 1 2 | tail -n +4 >> "io_stats_test_$1.txt"
      # Capture memory usage
      get_memory_usage >> "mem_usage_test_$1.txt"
      sleep $STATS_INTERVAL
    done
  ) &

  # Wait for the specified duration
  sleep $STRESS_DURATION

  # Stop CPU stress (suppressing the output)
  docker exec -it $CONTAINER_ID sh -c "for pid in \$(cat /tmp/yes_pids); do kill \$pid; done && rm /tmp/yes_pids" 2>/dev/null

  # Summarize the collected stats immediately after each test
  echo "Test $1 Summary:"
  echo "Average Load (over ${STRESS_DURATION} seconds):"
  awk '{ sum += $1; count++ } END { if (count > 0) printf "%.2f\n", sum/count }' "load_avg_test_$1.txt"

  echo "IO Stats:"
  awk 'BEGIN { printf "%-10s %-10s\n", "Reads/s", "Writes/s" }
       { if ($1 ~ /avg-cpu:/) { next } else if ($1 ~ /Device:/) { next } else { reads += $2; writes += $3; count++ } }
       END { if (count > 0) printf "%-10.2f %-10.2f\n", reads/count, writes/count }' "io_stats_test_$1.txt"

  echo "Memory Usage (in MB):"
  awk 'BEGIN { printf "%-10s %-10s %-10s\n", "Used", "Free", "Available" }
       { used += $1; free += $2; avail += $3; count++ }
       END { if (count > 0) printf "%-10.2f %-10.2f %-10.2f\n", used/count, free/count, avail/count }' "mem_usage_test_$1.txt"

  # Remove temporary files
  rm "load_avg_test_$1.txt" "io_stats_test_$1.txt" "mem_usage_test_$1.txt"
}

# Perform stress tests
for i in $(seq 1 $TEST_RUNS); do
  perform_stress_test $i
done

echo "CPU stress test completed."

