# Integration Tests Setup Guide

This guide explains how to set up and run integration tests for mojo-postgres on Ubuntu.

## Prerequisites

### System Requirements

- Ubuntu 20.04 or later (tested on Ubuntu 24.04)
- Mojo 24.5 or later
- Docker (for running PostgreSQL)
- Python 3.8+ (optional, for comparison benchmarks)

### Install Dependencies

```bash
# Update system packages
sudo apt update

# Install Docker (if not already installed)
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER  # Add your user to docker group
newgrp docker  # Activate the new group membership

# Verify Docker installation
docker --version
```

## PostgreSQL Test Database Setup

### Option 1: Using Docker (Recommended)

This is the easiest and most consistent way to run PostgreSQL for testing.

```bash
# Start PostgreSQL 16 container for testing
docker run -d \
  --name postgres-test \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=test \
  -e POSTGRES_USER=test \
  -e POSTGRES_DB=test \
  postgres:16

# Verify it's running
docker ps | grep postgres-test

# View logs
docker logs postgres-test

# Stop when done
docker stop postgres-test

# Remove container
docker rm postgres-test
```

### Option 2: Using Docker Compose

Create `tests/integration/docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    container_name: postgres-test
    environment:
      POSTGRES_USER: test
      POSTGRES_PASSWORD: test
      POSTGRES_DB: test
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test"]
      interval: 5s
      timeout: 5s
      retries: 5
```

Then run:

```bash
cd tests/integration
docker-compose up -d
docker-compose ps  # Verify running
docker-compose down  # Stop when done
```

### Option 3: Native PostgreSQL Installation

If you prefer to install PostgreSQL directly on Ubuntu:

```bash
# Install PostgreSQL 16
sudo apt install -y postgresql-16

# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create test user and database
sudo -u postgres psql -c "CREATE USER test WITH PASSWORD 'test';"
sudo -u postgres psql -c "CREATE DATABASE test OWNER test;"

# Verify connection
psql -h localhost -U test -d test -c "SELECT version();"
```

## Running Integration Tests

### Setup Helper Script

Use the provided setup script:

```bash
cd tests/integration
chmod +x setup_test_db.sh
./setup_test_db.sh
```

The script will:
1. Check if PostgreSQL is running
2. Create test database if needed
3. Verify connection

### Run Individual Integration Tests

```bash
# From project root
cd tests/integration

# Run connection test
mojo test_postgres_connection.mojo

# Run authentication test
mojo test_postgres_auth.mojo

# Run all integration tests
./run_all_tests.sh
```

### Expected Output

Successful test output should look like:

```
======================================================================
Running Integration Tests: PostgreSQL Connection
======================================================================

Test: Connect to PostgreSQL
  ✓ Connection established
  ✓ Authentication successful
  ✓ ReadyForQuery received
  ✓ Connection closed cleanly

Test: Connection Error Handling
  ✓ Invalid host raises ConnectionError
  ✓ Wrong password raises AuthenticationError
  ✓ Timeout handling works

======================================================================
✅ All integration tests passed!
======================================================================
```

## Configuration

### Default Connection Parameters

The tests use these default values:

```python
HOST = "localhost"
PORT = 5432
DATABASE = "test"
USER = "test"
PASSWORD = "test"
```

### Customizing Connection Parameters

You can override these with environment variables:

```bash
export PGHOST=myhost
export PGPORT=5433
export PGDATABASE=mydb
export PGUSER=myuser
export PGPASSWORD=mypassword

mojo test_postgres_connection.mojo
```

## Troubleshooting

### Connection Refused

**Symptom**: Error "Connection refused" or "Could not connect to server"

**Solutions**:
```bash
# Check if PostgreSQL is running
docker ps | grep postgres
# OR for native installation
sudo systemctl status postgresql

# Check if port 5432 is open
sudo netstat -tlnp | grep 5432
# OR
sudo ss -tlnp | grep 5432

# Try manual connection
psql -h localhost -U test -d test
```

### Authentication Failed

**Symptom**: Error "password authentication failed for user"

**Solutions**:
```bash
# Verify credentials
docker exec -it postgres-test psql -U test -d test

# Reset password in Docker
docker exec -it postgres-test psql -U postgres -c \
  "ALTER USER test WITH PASSWORD 'test';"

# For native installation
sudo -u postgres psql -c \
  "ALTER USER test WITH PASSWORD 'test';"
```

### Port Already in Use

**Symptom**: Error "port 5432 is already in use"

**Solutions**:
```bash
# Find what's using port 5432
sudo lsof -i :5432

# Stop existing PostgreSQL
docker stop postgres-test
# OR for native
sudo systemctl stop postgresql

# Use different port
docker run -d --name postgres-test -p 5433:5432 ...
export PGPORT=5433
```

### Permission Denied

**Symptom**: Error "permission denied" when accessing Docker

**Solutions**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# OR run with sudo (not recommended)
sudo docker run ...
```

### Slow Tests

**Symptom**: Tests take much longer than expected

**Possible causes**:
1. PostgreSQL running remotely (network latency)
2. Docker resource constraints
3. Disk I/O bottleneck

**Solutions**:
```bash
# Ensure PostgreSQL is on localhost
ping localhost

# Increase Docker resources (in Docker Desktop settings)
# - CPU: 2+ cores
# - Memory: 2+ GB

# Use tmpfs for PostgreSQL data (faster but ephemeral)
docker run -d \
  --tmpfs /var/lib/postgresql/data \
  --name postgres-test \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=test \
  postgres:16
```

## Testing Different PostgreSQL Versions

```bash
# PostgreSQL 12
docker run -d --name postgres-12-test -p 5432:5432 \
  -e POSTGRES_PASSWORD=test postgres:12

# PostgreSQL 14
docker run -d --name postgres-14-test -p 5432:5432 \
  -e POSTGRES_PASSWORD=test postgres:14

# PostgreSQL 16 (recommended)
docker run -d --name postgres-16-test -p 5432:5432 \
  -e POSTGRES_PASSWORD=test postgres:16
```

## Advanced: Testing with TimescaleDB

Since mojo-postgres targets TimescaleDB for time-series workloads:

```bash
# Run TimescaleDB container
docker run -d \
  --name timescaledb-test \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=test \
  timescale/timescaledb:latest-pg16

# Connect and create extension
docker exec -it timescaledb-test psql -U postgres -d test -c \
  "CREATE EXTENSION IF NOT EXISTS timescaledb;"

# Run tests
mojo test_postgres_connection.mojo
```

## Continuous Integration

For CI/CD pipelines (GitHub Actions, GitLab CI, etc.):

### GitHub Actions Example

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v3

      - name: Install Mojo
        run: |
          # Install Mojo (adjust for your setup)
          curl -ssL https://magic.modular.com | bash

      - name: Run Integration Tests
        run: |
          cd tests/integration
          mojo test_postgres_connection.mojo
```

## Cleanup

When you're done testing:

```bash
# Stop and remove Docker container
docker stop postgres-test
docker rm postgres-test

# OR if using docker-compose
cd tests/integration
docker-compose down -v  # -v removes volumes too

# For native PostgreSQL
sudo systemctl stop postgresql
```

## Getting Help

If you encounter issues not covered here:

1. Check PostgreSQL logs:
   ```bash
   docker logs postgres-test
   # OR for native
   sudo journalctl -u postgresql
   ```

2. Check mojo-postgres issues: https://github.com/yanbasile/mojo-postgres/issues

3. PostgreSQL documentation: https://www.postgresql.org/docs/

## Next Steps

After integration tests pass:

1. Run benchmarks to measure performance
2. Test with your production PostgreSQL configuration
3. Implement additional test cases for your use case
4. Set up continuous integration

Happy testing! 🔥
