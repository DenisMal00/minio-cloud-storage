#!/bin/bash

# Display help/usage
function show_help {
    echo "Usage: $0 <minio-endpoint> [file-size-in-MB] [number-of-tests]"
    echo "Example:"
    echo "  $0 https://localhost:9000 1000 5"
    echo "Arguments:"
    echo "  minio-endpoint   The endpoint URL for the MinIO server"
    echo "  file-size-in-MB  Size of the test file to create and upload in megabytes. Defaults to 10MB."
    echo "  number-of-tests  Number of times to run the test. Defaults to 3."
}

# Check for help command or if no MinIO endpoint is provided
if [[ "$1" == "--help" ]] || [[ "$#" -lt 1 ]]; then
    show_help
    exit 1
fi

# Configuration
MINIO_ENDPOINT="$1"
FILE_SIZE_MB="${2:-10}"
NUM_TESTS="${3:-3}"
MINIO_ALIAS="myminio"
ACCESS_KEY="admin"
SECRET_KEY="password"
BUCKET="test-bucket"
FILE="/tmp/test-file"
BYTES_SIZE=$((FILE_SIZE_MB * 1024 * 1024))  # Convert file size to bytes for speed calculation

# Get the MinIO container ID
CONTAINER_ID=$(docker ps -qf "name=minio$" 2>/dev/null)

if [ -z "$CONTAINER_ID" ]; then
  echo "Error: MinIO container is not running."
  exit 1
fi

echo "MinIO container ID: $CONTAINER_ID"

# Initialize variables to store total upload and download times
total_upload_time=0
total_download_time=0

# Execute commands inside the MinIO container
docker exec -it $CONTAINER_ID sh -c "
    mc alias set ${MINIO_ALIAS} ${MINIO_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY} --insecure 2>/dev/null

    if ! mc ls ${MINIO_ALIAS}/${BUCKET} &>/dev/null; then
        echo 'Creating bucket \"${BUCKET}\"...'
        mc mb --insecure ${MINIO_ALIAS}/${BUCKET} 2>/dev/null
    fi
"

for (( i=1; i<=NUM_TESTS; i++ ))
do
    echo "Running test $i/$NUM_TESTS..."
    
    # Create a test file
    docker exec -it $CONTAINER_ID sh -c "dd if=/dev/zero of=${FILE} bs=1M count=${FILE_SIZE_MB} status=none" 2>/dev/null

    # Upload the file and capture the time
    upload_start=$(date +%s.%N)
    docker exec -it $CONTAINER_ID sh -c "mc cp ${FILE} ${MINIO_ALIAS}/${BUCKET}/test-file --insecure" 2>/dev/null
    upload_end=$(date +%s.%N)
    upload_time=$(echo "$upload_end - $upload_start" | bc)
    total_upload_time=$(echo "$total_upload_time + $upload_time" | bc)

    # Download the file and capture the time
    download_start=$(date +%s.%N)
    docker exec -it $CONTAINER_ID sh -c "mc cp ${MINIO_ALIAS}/${BUCKET}/test-file ${FILE}.downloaded --insecure" 2>/dev/null
    download_end=$(date +%s.%N)
    download_time=$(echo "$download_end - $download_start" | bc)
    total_download_time=$(echo "$total_download_time + $download_time" | bc)

    # Cleanup
    docker exec -it $CONTAINER_ID sh -c "rm -f ${FILE} ${FILE}.downloaded && mc rm ${MINIO_ALIAS}/${BUCKET}/test-file --insecure" 2>/dev/null
done

# Calculate average upload and download times
avg_upload_time=$(echo "scale=2; $total_upload_time / $NUM_TESTS" | bc)
avg_download_time=$(echo "scale=2; $total_download_time / $NUM_TESTS" | bc)

# Calculate average upload and download speeds
avg_upload_speed=$(echo "scale=2; $BYTES_SIZE / $avg_upload_time / (1024 * 1024)" | bc)
avg_download_speed=$(echo "scale=2; $BYTES_SIZE / $avg_download_time / (1024 * 1024)" | bc)

# Clean up the test bucket
docker exec -it $CONTAINER_ID sh -c "mc rb --force ${MINIO_ALIAS}/${BUCKET} --insecure" 2>/dev/null

echo "Average upload time: ${avg_upload_time}s"
echo "Average download time: ${avg_download_time}s"
echo "Average upload speed: ${avg_upload_speed} MB/s"
echo "Average download speed: ${avg_download_speed} MB/s"
echo "Performance test completed."

