#!/bin/bash

# Function to create a test file of specified size in MB
create_test_file() {
  dd if=/dev/urandom of=$1 bs=1M count=$2 &> /dev/null
}

# Function to calculate speed in MB/s
calculate_speed() {
  local start_time=$1
  local end_time=$2
  local size_mb=$3
  local duration=$(echo "$end_time - $start_time" | bc -l)
  local speed=$(echo "scale=2; $size_mb / $duration" | bc -l)
  echo $speed
}

# Check if the number of arguments is correct
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <file_size_in_mb>"
  exit 1
fi

# Configuration variables
FILE_SIZE_MB=$1
FILE_NAME="testfile.tmp"
FILE_NAME_DOWNLOADED="testfile.tmp.downloaded"
BUCKET_NAME="test-bucket"
MINIO_ALIAS="localminio"
ENDPOINT="https://localhost:9000"
ACCESS_KEY="admin"
SECRET_KEY="password"

# Configure the mc client
mc alias set $MINIO_ALIAS $ENDPOINT $ACCESS_KEY $SECRET_KEY --insecure &> /dev/null

# Create the bucket if it doesn't exist
mc mb --insecure --ignore-existing $MINIO_ALIAS/$BUCKET_NAME &> /dev/null

# Create the test file
create_test_file $FILE_NAME $FILE_SIZE_MB

# Upload the file and measure the time
start_time=$(date +%s.%N)
mc cp --insecure $FILE_NAME $MINIO_ALIAS/$BUCKET_NAME &> /dev/null
end_time=$(date +%s.%N)
upload_speed=$(calculate_speed $start_time $end_time $FILE_SIZE_MB)
echo "Upload speed: $upload_speed MB/s"

# Download the file and measure the time
start_time=$(date +%s.%N)
mc cp --insecure $MINIO_ALIAS/$BUCKET_NAME/$FILE_NAME $FILE_NAME_DOWNLOADED &> /dev/null
end_time=$(date +%s.%N)
download_speed=$(calculate_speed $start_time $end_time $FILE_SIZE_MB)
echo "Download speed: $download_speed MB/s"

# Cleanup
rm -f $FILE_NAME $FILE_NAME_DOWNLOADED
mc rm --insecure $MINIO_ALIAS/$BUCKET_NAME/$FILE_NAME &> /dev/null
mc rb --insecure $MINIO_ALIAS/$BUCKET_NAME --force &> /dev/null

