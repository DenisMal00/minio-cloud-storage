#!/bin/bash

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

# Initialize variables to store total upload and download times
total_upload_time=0
total_download_time=0

# Execute commands inside the MinIO container
echo "Setting up MinIO alias and bucket..."
setup_start=$(date +%s.%N)
docker exec -it $CONTAINER_ID sh -c "
    mc alias set ${MINIO_ALIAS} ${MINIO_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY} --insecure 2>/dev/null

    if ! mc ls ${MINIO_ALIAS}/${BUCKET} &>/dev/null; then
        mc mb --insecure ${MINIO_ALIAS}/${BUCKET} 2>/dev/null
    fi
" 2>/dev/null
setup_end=$(date +%s.%N)
setup_time=$(echo "$setup_end - $setup_start" | bc)
echo "Setup time: ${setup_time}s"

for (( i=1; i<=NUM_TESTS; i++ ))
do
    echo "Running test $i/$NUM_TESTS..."
    
    # Create a test file
    create_start=$(date +%s.%N)
    docker exec -it $CONTAINER_ID sh -c "dd if=/dev/zero of=${FILE} bs=1M count=${FILE_SIZE_MB} status=none" 2>/dev/null
    create_end=$(date +%s.%N)
    create_time=$(echo "$create_end - $create_start" | bc)
    echo "File creation time: ${create_time}s"

    # Upload the file and capture the time
    upload_start=$(date +%s.%N)
    docker exec -it $CONTAINER_ID sh -c "mc cp ${FILE} ${MINIO_ALIAS}/${BUCKET}/test-file --insecure" 2>/dev/null
    upload_end=$(date +%s.%N)
    upload_time=$(echo "$upload_end - $upload_start" | bc)
    total_upload_time=$(echo "$total_upload_time + $upload_time" | bc)
    echo "Upload time: ${upload_time}s"

    # Download the file and capture the time
    download_start=$(date +%s.%N)
    docker exec -it $CONTAINER_ID sh -c "mc cp ${MINIO_ALIAS}/${BUCKET}/test-file ${FILE}.downloaded --insecure" 2>/dev/null
    download_end=$(date +%s.%N)
    download_time=$(echo "$download_end - $download_start" | bc)
    total_download_time=$(echo "$total_download_time + $download_time" | bc)
    echo "Download time: ${download_time}s"

    # Cleanup
    cleanup_start=$(date +%s.%N)
    docker exec -it $CONTAINER_ID sh -c "rm -f ${FILE} ${FILE}.downloaded && mc rm ${MINIO_ALIAS}/${BUCKET}/test-file --insecure" 2>/dev/null
    cleanup_end=$(date +%s.%N)
    cleanup_time=$(echo "$cleanup_end - $cleanup_start" | bc)
    echo "Cleanup time: ${cleanup_time}s"
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

