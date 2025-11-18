# Tencent CVM Deployment Guide

This guide provides comprehensive instructions for deploying the AIGC Chatbot application on Tencent Cloud Virtual Machine (CVM) using Docker and Docker Compose with systemd for service management.

## Table of Contents

1. [Server Prerequisites](#server-prerequisites)
2. [Environment Setup](#environment-setup)
3. [Deployment Assets Installation](#deployment-assets-installation)
4. [Service Configuration](#service-configuration)
5. [Enabling the Service](#enabling-the-service)
6. [Monitoring and Health Checks](#monitoring-and-health-checks)
7. [Troubleshooting](#troubleshooting)
8. [CI/CD Pipeline Integration](#cicd-pipeline-integration)

## Server Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04 LTS or later (or CentOS 7+)
- **CPU**: Minimum 2 cores
- **RAM**: Minimum 4GB (8GB+ recommended)
- **Storage**: Minimum 20GB free space (50GB+ recommended for image storage)
- **Network**: Stable internet connection for pulling images

### 1. Install Docker

Install the latest version of Docker from the official repository:

```bash
# Update package index
sudo apt-get update

# Install Docker dependencies
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Start Docker daemon
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
docker --version
```

### 2. Install Docker Compose Plugin

Install the Docker Compose plugin (recommended over standalone docker-compose):

```bash
# Install Docker Compose V2 plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.25.0/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify installation
docker compose version

# For convenience, also install standalone docker-compose
sudo apt-get install -y docker-compose-plugin

# Or install via pip
sudo apt-get install -y python3-pip
sudo pip3 install docker-compose
docker-compose --version
```

### 3. Configure Tencent Container Registry Access

Set up access to Tencent Container Registry (CCR):

```bash
# Create Docker login credentials for Tencent CCR
# Replace with your actual credentials from Tencent Cloud console
sudo mkdir -p ~/.docker

# Generate credentials file (you can also login interactively)
cat <<EOF > ~/.docker/config.json
{
  "auths": {
    "ccr.ccs.tencentyun.com": {
      "auth": "$(echo -n 'YOUR_USERNAME:YOUR_PASSWORD' | base64)"
    }
  }
}
EOF

# Or login interactively:
docker login -u YOUR_USERNAME ccr.ccs.tencentyun.com
# Enter password when prompted

# Verify login
docker pull ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:latest
```

**Note**: To obtain your Tencent CCR credentials:
1. Visit [Tencent Cloud Console](https://console.cloud.tencent.com/)
2. Navigate to Container Registry (容器镜像服务)
3. Go to "Personal Namespace" or your organization namespace
4. Click "Access Credentials" to view username and password

### 4. Configure Registry Mirror (Optional but Recommended)

Speed up image pulling by configuring mirror sources:

```bash
# Create or edit Docker daemon configuration
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com",
    "https://dqd6soan.mirror.aliyuncs.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Reload Docker daemon
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 5. Grant User Docker Permissions (Optional)

Allow running Docker commands without sudo:

```bash
# Create docker group if it doesn't exist
sudo groupadd -f docker

# Add current user to docker group
sudo usermod -aG docker $USER

# Apply new group membership
newgrp docker

# Verify
docker ps
```

## Environment Setup

### 1. Create Application Directory

```bash
# Create deployment directory
sudo mkdir -p /opt/aigc-chatbot
sudo chown $USER:$USER /opt/aigc-chatbot
cd /opt/aigc-chatbot
```

### 2. Prepare Environment Files

Create the production environment file at `/opt/aigc-chatbot/.env.production`:

```bash
# Copy from the project's .env.example
cp .env.example .env.production

# Edit the environment file with production values
nano /opt/aigc-chatbot/.env.production
```

**Minimum required variables for Tencent CVM deployment**:

```bash
# Authentication
AUTH_SECRET=your-random-secret-key-32-characters-or-more

# AI Gateway and Models
AI_GATEWAY_API_KEY=your-ai-gateway-key
OPENAI_API_URL=https://your-gateway-domain/v1
OPENAI_CHAT_MODEL=qwen-max
OPENAI_REASONING_MODEL=qwen-max
OPENAI_TITLE_MODEL=qwen-max
OPENAI_ARTIFACT_MODEL=qwen-max

# Display names
NEXT_PUBLIC_OPENAI_CHAT_MODEL_DISPLAY_NAME=QWen Max
NEXT_PUBLIC_OPENAI_REASONING_MODEL_DISPLAY_NAME=QWen Max

# Database (PostgreSQL)
POSTGRES_URL=postgresql://user:password@postgres-host:5432/aigc_chatbot

# Blob Storage (Vercel Blob or compatible S3)
BLOB_READ_WRITE_TOKEN=your-blob-token

# Redis (for resumable streaming, optional)
REDIS_URL=redis://redis-host:6379/0

# Application Settings
NODE_ENV=production
```

### 3. Optional: Create Local Override File

For sensitive credentials or local-only settings:

```bash
# Create optional local override file
touch /opt/aigc-chatbot/.env.production.local

# Add environment-specific overrides
echo "REGISTRY_PASSWORD=your-tencent-ccr-password" >> /opt/aigc-chatbot/.env.production.local

# Restrict permissions
chmod 600 /opt/aigc-chatbot/.env.production.local
```

### 4. Create Docker Compose Configuration

Create `/opt/aigc-chatbot/docker-compose.yml`:

```yaml
version: "3.9"

services:
  aigc-chatbot:
    image: ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:latest
    container_name: aigc-chatbot
    restart: on-failure
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - PORT=3000
    env_file:
      - .env.production
    volumes:
      - aigc-data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - aigc-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Optional: PostgreSQL for local database
  postgres:
    image: postgres:15-alpine
    container_name: aigc-postgres
    restart: on-failure
    environment:
      POSTGRES_DB: aigc_chatbot
      POSTGRES_USER: ${DB_USER:-postgres}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-password}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - aigc-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Optional: Redis for resumable streaming
  redis:
    image: redis:7-alpine
    container_name: aigc-redis
    restart: on-failure
    command: redis-server --appendonly yes
    volumes:
      - redis-data:/data
    networks:
      - aigc-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  aigc-data:
  postgres-data:
  redis-data:

networks:
  aigc-network:
    driver: bridge
```

## Deployment Assets Installation

### 1. Copy Deployment Script

```bash
# Copy the deployment script to the application directory
cp deploy/tencent-cvm-deploy.sh /opt/aigc-chatbot/deploy/

# Make it executable
chmod +x /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh

# Verify script syntax with shellcheck (install if needed: apt-get install -y shellcheck)
shellcheck /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh
```

### 2. Copy Systemd Service Unit

```bash
# Copy the systemd service template
sudo cp deploy/aigc-chatbot.service /etc/systemd/system/

# Set proper permissions
sudo chmod 644 /etc/systemd/system/aigc-chatbot.service

# Reload systemd daemon to recognize the new service
sudo systemctl daemon-reload
```

## Service Configuration

### 1. Verify Systemd Unit File

Check the service unit file is correctly installed:

```bash
# Display the service file
sudo cat /etc/systemd/system/aigc-chatbot.service

# Check for syntax errors
systemd-analyze verify /etc/systemd/system/aigc-chatbot.service
```

### 2. Configure Service Variables

The systemd service reads two environment files in order:
1. `/opt/aigc-chatbot/.env.production` (main configuration)
2. `/opt/aigc-chatbot/.env.production.local` (local overrides, optional)

Ensure these files exist with proper permissions:

```bash
# Verify environment files
ls -la /opt/aigc-chatbot/.env.production*

# Set restrictive permissions
chmod 640 /opt/aigc-chatbot/.env.production
chmod 600 /opt/aigc-chatbot/.env.production.local 2>/dev/null || true
```

## Enabling the Service

### 1. Enable Automatic Startup

```bash
# Enable the service to start automatically on boot
sudo systemctl enable aigc-chatbot.service

# Verify it's enabled
sudo systemctl is-enabled aigc-chatbot.service
```

### 2. Start the Service

```bash
# Start the service immediately
sudo systemctl start aigc-chatbot.service

# Check service status
sudo systemctl status aigc-chatbot.service

# If there are issues, see Troubleshooting section
```

### 3. Verify Deployment

```bash
# Check if container is running
docker ps | grep aigc-chatbot

# Test the application endpoint
curl -s http://localhost:3000 | head -20

# View recent container logs
docker logs -f aigc-chatbot --tail=50
```

## Monitoring and Health Checks

### 1. Systemd Service Status

```bash
# Check service status
sudo systemctl status aigc-chatbot.service

# View service journal logs
sudo journalctl -u aigc-chatbot.service -f

# View last 100 lines of service logs
sudo journalctl -u aigc-chatbot.service -n 100

# View logs from a specific time period
sudo journalctl -u aigc-chatbot.service --since "2 hours ago"
```

### 2. Docker Container Health

```bash
# Check container health status
docker inspect aigc-chatbot --format='{{.State.Health.Status}}'

# View full container inspection
docker inspect aigc-chatbot

# Check container logs
docker logs aigc-chatbot

# Stream container logs in real-time
docker logs -f aigc-chatbot --tail=100

# View container resource usage
docker stats aigc-chatbot
```

### 3. Application Monitoring

```bash
# Check if application is responding
curl -i http://localhost:3000

# Check API health endpoint (if available)
curl -i http://localhost:3000/api/health

# Check port is listening
netstat -tlnp | grep 3000
# or
ss -tlnp | grep 3000
```

### 4. System Resource Monitoring

```bash
# Check disk usage
df -h

# Check memory usage
free -h

# Check Docker disk usage
docker system df

# Check running processes
top -b -n 1 | grep -E "docker|node"
```

### 5. Log Aggregation (Optional)

Set up centralized logging for better monitoring:

```bash
# Check Docker log driver configuration
docker inspect aigc-chatbot | grep -A 20 LogConfig

# View logs from all containers
docker-compose logs -f

# Export logs for analysis
docker logs aigc-chatbot > /tmp/aigc-chatbot.log 2>&1
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Service Fails to Start

**Symptoms**: `systemctl status aigc-chatbot.service` shows failure

**Solutions**:
```bash
# Check service logs for details
sudo journalctl -u aigc-chatbot.service -n 50 -p err

# Verify environment files exist and are readable
ls -la /opt/aigc-chatbot/.env.production*

# Test the deploy script manually
cd /opt/aigc-chatbot
bash -x deploy/tencent-cvm-deploy.sh

# Check Docker daemon is running
sudo systemctl status docker

# Restart Docker if needed
sudo systemctl restart docker
```

#### 2. Image Pull Fails

**Symptoms**: Deployment script fails at image pull step

**Solutions**:
```bash
# Verify registry login
docker login ccr.ccs.tencentyun.com

# Check Docker credentials
cat ~/.docker/config.json | jq .

# Test image pull manually
docker pull ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:latest

# Check network connectivity
ping -c 3 ccr.ccs.tencentyun.com
nslookup ccr.ccs.tencentyun.com

# Verify image exists in registry
# Check from Tencent Cloud console or use curl to query API
```

#### 3. Port Already in Use

**Symptoms**: Docker container fails to start with port binding error

**Solutions**:
```bash
# Find process using port 3000
sudo lsof -i :3000
# or
sudo netstat -tlnp | grep 3000

# Kill the process
sudo kill -9 <PID>

# Or use different port in docker-compose.yml
# Change "3000:3000" to "3001:3000"
```

#### 4. Out of Disk Space

**Symptoms**: Docker fails with "no space left on device"

**Solutions**:
```bash
# Check disk usage
df -h

# Clean up Docker system
docker system prune -a -f

# Remove old images
docker image prune -a -f

# Remove dangling volumes
docker volume prune -f

# Check specific image sizes
docker images --format "table {{.Repository}}\t{{.Size}}"

# View log file size
du -sh /var/lib/docker/containers/*
```

#### 5. Container Exits Immediately

**Symptoms**: Container starts then stops within seconds

**Solutions**:
```bash
# Check container logs
docker logs aigc-chatbot

# Check for missing environment variables
docker-compose config

# Verify environment file syntax
cat /opt/aigc-chatbot/.env.production | grep -v '^#' | grep -v '^$'

# Run container in interactive mode for debugging
docker-compose run --rm aigc-chatbot sh
```

#### 6. Health Check Failing

**Symptoms**: Container marked as unhealthy despite running

**Solutions**:
```bash
# Check health status
docker inspect aigc-chatbot --format='{{.State.Health}}'

# Manually test the health endpoint
docker exec aigc-chatbot curl -i http://localhost:3000/api/health

# Check container network
docker inspect aigc-chatbot --format='{{.NetworkSettings.Networks}}'

# Increase health check timeout in docker-compose.yml if needed
```

#### 7. Permission Denied Errors

**Symptoms**: Script execution fails with permission denied

**Solutions**:
```bash
# Verify script is executable
ls -la /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh

# Make script executable
chmod +x /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh

# Verify user has docker access
groups $USER | grep docker

# Add user to docker group if needed
sudo usermod -aG docker $USER
newgrp docker
```

### Debug Mode

For detailed troubleshooting, run the deployment script in debug mode:

```bash
# Run script with set -x for command execution tracing
bash -x /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh

# Increase logging level
export LOG_FILE=/tmp/deploy-debug.log
bash -x /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh

# Capture all output
bash -x /opt/aigc-chatbot/deploy/tencent-cvm-deploy.sh 2>&1 | tee /tmp/deploy.log
```

## CI/CD Pipeline Integration

### CI Pipeline Expectations

The CI/CD pipeline expects the following:

#### File Paths
- Deployment script: `deploy/tencent-cvm-deploy.sh`
- Systemd unit: `deploy/aigc-chatbot.service`
- Documentation: `docs/deployment/tencent-cvm.md`

#### Script Requirements
- Must be shell scripts (sh/bash compatible)
- Must pass `shellcheck` validation
- Must use `set -euo pipefail` for error handling
- Must be executable (chmod +x)
- Should support environment variable configuration
- Must log all operations for audit trail

#### Environment Variables
The CI pipeline sets these environment variables for deployment:

```bash
REGISTRY_URL=ccr.ccs.tencentyun.com
NAMESPACE=your-namespace
IMAGE_NAME=aigc-chatbot
IMAGE_TAG=<git-commit-sha or latest>
REGISTRY_USERNAME=<from CI secrets>
REGISTRY_PASSWORD=<from CI secrets>
COMPOSE_DIR=/opt/aigc-chatbot
ENV_FILE=/opt/aigc-chatbot/.env.production
```

#### Expected Script Exit Codes
- `0`: Successful deployment
- `1`: Any error condition (script exits with `error_exit`)
- Non-zero: Any unhandled error

#### Logging
All operations are logged to:
- Stdout for CI console output
- `/var/log/aigc-chatbot-deploy.log` on the server

### Manual Deployment via CI

If setting up CI/CD, the pipeline typically:

1. Builds Docker image locally
2. Tags with commit SHA or "latest"
3. Pushes to Tencent CCR
4. SSHes into CVM server
5. Runs deployment script:
   ```bash
   ssh -i /path/to/key ubuntu@server-ip \
     "cd /opt/aigc-chatbot && \
      export IMAGE_TAG=v1.2.3 && \
      bash deploy/tencent-cvm-deploy.sh"
   ```

### Rollback Procedure

To rollback to a previous version:

```bash
# Stop current deployment
sudo systemctl stop aigc-chatbot.service

# List available images
docker image ls | grep aigc-chatbot

# Pull specific version
docker pull ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:v1.2.2

# Update docker-compose image tag and restart
export IMAGE_TAG=v1.2.2
sudo systemctl start aigc-chatbot.service

# Verify rollback
docker ps | grep aigc-chatbot
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [Tencent CCR Documentation](https://cloud.tencent.com/document/product/1141)
- [Application README](../../README.md)

## Support and Questions

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review service logs: `sudo journalctl -u aigc-chatbot.service`
3. Check container logs: `docker logs aigc-chatbot`
4. Review deployment script logs: `/var/log/aigc-chatbot-deploy.log`
5. Contact the development team with:
   - Error messages and full logs
   - System information (OS version, Docker version, etc.)
   - Steps to reproduce the issue
