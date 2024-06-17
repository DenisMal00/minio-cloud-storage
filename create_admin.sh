#!/bin/bash

# Check if the username is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <username>"
  exit 1
fi

# Configuration
MINIO_ENDPOINT="https://localhost:9000"  # Use the first script argument as the MinIO endpoint
MINIO_ALIAS="myminio"
ACCESS_KEY="admin"
SECRET_KEY="password"
USER="$1"
USER_POLICY="consoleAdmin"

# Get the MinIO container ID
CONTAINER_ID=$(docker ps -qf "name=minio$")

if [ -z "$CONTAINER_ID" ]; then
  echo "Error: MinIO container is not running."
  exit 1
fi

echo "MinIO container ID: $CONTAINER_ID"

# Generate a random password for the user
USER_PASSWORD=$(openssl rand -base64 12)

# Execute commands inside the MinIO container
docker exec -it $CONTAINER_ID sh -c "
    mc alias set ${MINIO_ALIAS} ${MINIO_ENDPOINT} ${ACCESS_KEY} ${SECRET_KEY} --insecure

    echo 'Creating admin user \"${USER}\"...'
    mc admin user add --insecure ${MINIO_ALIAS} ${USER} ${USER_PASSWORD}
    mc admin policy attach --insecure ${MINIO_ALIAS} ${USER_POLICY} --user=${USER}
"

echo "Admin user \"${USER}\" created with password: ${USER_PASSWORD}"

