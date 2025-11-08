#!/bin/bash
#
# Setup script for PostgreSQL integration test database
#
# This script:
# 1. Checks if PostgreSQL is running
# 2. Starts PostgreSQL in Docker if needed
# 3. Verifies the connection
# 4. Creates test database if needed

set -e  # Exit on error

# Configuration
CONTAINER_NAME="postgres-test"
POSTGRES_VERSION="16"
POSTGRES_USER="test"
POSTGRES_PASSWORD="test"
POSTGRES_DB="test"
POSTGRES_PORT="5432"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================================================="
echo "PostgreSQL Integration Test Database Setup"
echo "======================================================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Install Docker first:"
    echo "  sudo apt install -y docker.io"
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker is installed"

# Check if PostgreSQL is already running
if docker ps | grep -q $CONTAINER_NAME; then
    echo -e "${GREEN}✓${NC} PostgreSQL container is already running"
    RUNNING=true
elif docker ps -a | grep -q $CONTAINER_NAME; then
    echo -e "${YELLOW}⚠${NC}  PostgreSQL container exists but is stopped"
    echo "Starting container..."
    docker start $CONTAINER_NAME
    RUNNING=true
else
    echo "Creating new PostgreSQL container..."
    docker run -d \
      --name $CONTAINER_NAME \
      -p $POSTGRES_PORT:5432 \
      -e POSTGRES_USER=$POSTGRES_USER \
      -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
      -e POSTGRES_DB=$POSTGRES_DB \
      postgres:$POSTGRES_VERSION

    RUNNING=true
    echo -e "${GREEN}✓${NC} PostgreSQL container created"
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
    if docker exec $CONTAINER_NAME pg_isready -U $POSTGRES_USER &> /dev/null; then
        echo -e "${GREEN}✓${NC} PostgreSQL is ready"
        break
    fi

    if [ $i -eq 30 ]; then
        echo -e "${RED}❌ PostgreSQL failed to start within 30 seconds${NC}"
        echo "Check logs with: docker logs $CONTAINER_NAME"
        exit 1
    fi

    echo -n "."
    sleep 1
done

# Verify connection
echo ""
echo "Verifying connection..."
if docker exec $CONTAINER_NAME psql -U $POSTGRES_USER -d $POSTGRES_DB -c "SELECT version();" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Connection successful"
else
    echo -e "${RED}❌ Connection failed${NC}"
    exit 1
fi

# Display connection info
echo ""
echo "======================================================================="
echo "PostgreSQL Test Database is Ready"
echo "======================================================================="
echo "Connection details:"
echo "  Host:     localhost"
echo "  Port:     $POSTGRES_PORT"
echo "  Database: $POSTGRES_DB"
echo "  User:     $POSTGRES_USER"
echo "  Password: $POSTGRES_PASSWORD"
echo ""
echo "Test connection:"
echo "  docker exec -it $CONTAINER_NAME psql -U $POSTGRES_USER -d $POSTGRES_DB"
echo ""
echo "Stop database:"
echo "  docker stop $CONTAINER_NAME"
echo ""
echo "Remove database:"
echo "  docker rm $CONTAINER_NAME"
echo "======================================================================="

# Get PostgreSQL version
VERSION=$(docker exec $CONTAINER_NAME psql -U $POSTGRES_USER -d $POSTGRES_DB -t -c "SELECT version();" | head -n1)
echo "PostgreSQL version:"
echo "  $VERSION"

echo ""
echo -e "${GREEN}✅ Setup complete!${NC} You can now run integration tests."
echo ""
echo "Run tests with:"
echo "  cd tests/integration"
echo "  mojo test_postgres_connection.mojo"
echo "======================================================================="
