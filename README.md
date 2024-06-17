
# Cloud-Based File Storage System

This repository contains the implementation of a cloud-based file storage system using MinIO, Prometheus, and Grafana. The system allows users to upload, download, and delete files in a private storage space. Admins have additional capabilities to manage users.

## Prerequisites

- Docker
- Docker Compose

## Setup and Run

### 1. Clone the Repository

```bash
git clone https://github.com/DenisMal00/minio-cloud-storage.git
cd minio-cloud-storage
```
### 2. Set Permissions for Volumes
Run these commands to set the correct permissions for the volumes:

```bash
Copia codice
docker run --rm -v minio-cloud-storage_minio_data:/data -v minio-cloud-storage_minio_certs:/certs alpine ls -ld /data /certs
docker run --rm -v minio-cloud-storage_minio_data:/data -v minio-cloud-storage_minio_certs:/certs alpine sh -c "chown -R 1000:1000 /data /certs && chmod -R u+rw /data /certs"
```

### 3. Run Docker Compose

Execute the following command to start all services:

```bash
docker-compose up -d
```

This command will start the following services:
- **MinIO**: Object storage service
- **Prometheus**: Monitoring service
- **Grafana**: Metrics visualization

### 4. Access the Services

- **MinIO**: [https://localhost](https://localhost)
  - Default credentials:
    - Username: `admin`
    - Password: `password`
 - To avoid security warnings, you can add the self-signed certificate to your trusted certificates store. The certificate can be found in the `certs/ca` directory of this repository.


- **Prometheus**: [http://localhost:9090](http://localhost:9090)

- **Grafana**: [http://localhost:3000](http://localhost:3000)
  - Default credentials:
    - Username: `admin`
    - Password: `admin`

### 5. Create Users

**Regular User**

To create a regular user, run the `create_user.sh` script:

```bash
./create_user.sh USERNAME
```

Replace `USERNAME` with the desired username. The script will output the generated password.

**Admin User**

To create an admin user, run the `create_admin.sh` script:

```bash
./create_admin.sh ADMIN_USERNAME
```

Replace `ADMIN_USERNAME` with the desired username. The script will output the generated password.

### 6. Monitor and Manage

Use Prometheus and Grafana to monitor system performance and visualize metrics. Configure alerts and notifications in Grafana to manage the deployed system proactively.

## Performance Testing

**File Operations**

To test file operations (upload, download, delete), use the `performance_test.sh` script:

```bash
./performance_test.sh FILE_SIZE_MB
```

- `FILE_SIZE_MB`: Size of the test file in megabytes.

**CPU Stress Test**

To stress test the CPU, use the `cpu_stress_test.sh` script:

```bash
./cpu_stress_test.sh NUM_ITERATIONS
```
- `NUM_ITERATIONS`: Number of iterations to perform.

## Clean Up

To stop and remove all containers, networks, and volumes created by Docker Compose:

```bash
docker-compose down -v
```
