# Tencent CVM Deployment Guide

This guide provides comprehensive instructions for deploying the AIGC Chatbot application on Tencent Cloud Virtual Machine (CVM) using Docker and Docker Compose with local builds.

## Table of Contents

1. [Server Prerequisites](#server-prerequisites)
2. [Environment Setup](#environment-setup)
3. [Initial Deployment](#initial-deployment)
4. [Service Configuration](#service-configuration)
5. [Monitoring and Health Checks](#monitoring-and-health-checks)
6. [Troubleshooting](#troubleshooting)
7. [CI/CD Pipeline Integration](#cicd-pipeline-integration)

## Server Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04 LTS or later (or CentOS 7+)
- **CPU**: Minimum 2 cores
- **RAM**: Minimum 4GB (8GB+ recommended)
- **Storage**: Minimum 20GB free space (50GB+ recommended for image storage)
- **Network**: Stable internet connection for pulling code

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

### 3. Install Git

Install Git for pulling code updates:

```bash
# Install git
sudo apt-get update
sudo apt-get install -y git

# Verify installation
git --version
```

### 4. Grant User Docker Permissions (Optional)

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

### 1. Clone Repository

```bash
# Create deployment directory
sudo mkdir -p /app
sudo chown $USER:$USER /app

# Clone the repository
cd /app
git clone <your-repo-url> .

# Alternatively, if using a specific branch:
# git clone -b main <your-repo-url> .
```

### 2. Prepare Environment Files

Create the production environment file at `/app/.env.production`:

```bash
# Copy from the project's .env.example
cp .env.example .env.production

# Edit the environment file with production values
nano /app/.env.production
```

**Minimum required variables for Tencent CVM deployment**:

```bash
# Authentication
AUTH_SECRET=your-random-secret-key-32-characters-or-more
NEXTAUTH_SECRET=your-random-secret-key-32-characters-or-more

# Application URL - IMPORTANT: Must match exactly how you access the app
# For IP-based deployment: NEXTAUTH_URL=http://122.51.119.81:3000
# For domain-based deployment: NEXTAUTH_URL=https://your-domain.com
NEXTAUTH_URL=http://122.51.119.81:3000

# AI Gateway and Models
OPENAI_API_KEY=your-openai-api-key
OPENAI_API_URL=https://api.openai.com/v1
OPENAI_CHAT_MODEL=gpt-4o
OPENAI_REASONING_MODEL=gpt-4o-mini
OPENAI_TITLE_MODEL=gpt-4o-mini
OPENAI_ARTIFACT_MODEL=gpt-4o

# Display names
NEXT_PUBLIC_OPENAI_CHAT_MODEL_DISPLAY_NAME=GPT-4o
NEXT_PUBLIC_OPENAI_REASONING_MODEL_DISPLAY_NAME=GPT-4o Mini

# Database (PostgreSQL)
POSTGRES_URL=postgresql://user:password@postgres-host:5432/aigc_chatbot

# Blob Storage (Vercel Blob or compatible S3) - optional
BLOB_READ_WRITE_TOKEN=your-blob-token

# Redis (for resumable streaming, optional)
REDIS_URL=redis://redis-host:6379/0

# Application Settings
NODE_ENV=production
PORT=3000
```

### 3. Set File Permissions

```bash
# Restrict permissions on environment file
chmod 600 /app/.env.production
```

### 4. Verify Docker Compose Configuration

The repository includes a `docker-compose.yml` file that builds the image locally:

```yaml
version: "3.8"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ai-chatbot
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      NODE_ENV: production
    env_file:
      - .env.production
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 40s
    networks:
      - app-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  app-network:
    driver: bridge
```

This configuration uses local builds instead of pulling from a container registry.

## Initial Deployment

### 1. Build and Start Services

```bash
# Navigate to the application directory
cd /app

# Build the Docker image
docker compose build

# Start the services
docker compose up -d

# Verify containers are running
docker ps

# Check logs
docker compose logs -f
```

### 2. Verify Deployment

```bash
# Check if container is running
docker ps | grep ai-chatbot

# Test the application endpoint
curl -s http://localhost:3000 | head -20

# View recent container logs
docker logs -f ai-chatbot --tail=50
```

### 3. Optional: Setup Systemd Service

If you want to manage the application as a systemd service:

```bash
# Copy the systemd service template
sudo cp deploy/aigc-chatbot.service /etc/systemd/system/

# Set proper permissions
sudo chmod 644 /etc/systemd/system/aigc-chatbot.service

# Reload systemd daemon to recognize the new service
sudo systemctl daemon-reload

# Enable and start the service
sudo systemctl enable aigc-chatbot.service
sudo systemctl start aigc-chatbot.service

# Check service status
sudo systemctl status aigc-chatbot.service
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

The systemd service reads environment files:
- `/app/.env.production` (main configuration)

Ensure these files exist with proper permissions:

```bash
# Verify environment files
ls -la /app/.env.production

# Set restrictive permissions
chmod 600 /app/.env.production
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
docker inspect ai-chatbot --format='{{.State.Health.Status}}'

# View full container inspection
docker inspect ai-chatbot

# Check container logs
docker logs ai-chatbot

# Stream container logs in real-time
docker logs -f ai-chatbot --tail=100

# View container resource usage
docker stats ai-chatbot
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
docker inspect ai-chatbot | grep -A 20 LogConfig

# View logs from all containers
docker compose logs -f

# Export logs for analysis
docker logs ai-chatbot > /tmp/ai-chatbot.log 2>&1
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
ls -la /app/.env.production

# Test the deploy script manually
cd /app
bash -x deploy/tencent-cvm-deploy.sh

# Check Docker daemon is running
sudo systemctl status docker

# Restart Docker if needed
sudo systemctl restart docker
```

#### 2. Docker Build Fails

**Symptoms**: Deployment script fails at docker build step

**Solutions**:
```bash
# Check build logs
docker compose build --no-cache

# Verify Dockerfile exists
ls -la Dockerfile

# Check disk space
df -h

# Clean up Docker build cache
docker builder prune -a -f

# Try building manually
docker build -t ai-chatbot .
```

#### 3. Git Pull Fails

**Symptoms**: Deployment script fails at git pull step

**Solutions**:
```bash
# Check git status
cd /app
git status

# Verify remote is configured
git remote -v

# Test connectivity to git server
ping -c 3 github.com  # or your git host

# Reset to clean state
git fetch origin
git reset --hard origin/main

# Check git permissions
ls -la .git
```

#### 4. Port Already in Use

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

#### 5. NextAuth UntrustedHost Error

**Symptoms**: Authentication fails with error "UntrustedHost: Host must be trusted. URL was: http://122.51.119.81:3000/api/auth/session"

**Solutions**:
```bash
# 1. Verify NEXTAUTH_URL matches exactly how you access the app
# Check your environment file
grep NEXTAUTH_URL /app/.env.production

# 2. Ensure the URL includes protocol, IP/domain, and port
# Correct examples:
# - http://122.51.119.81:3000 (IP-based deployment)
# - https://your-domain.com (domain-based deployment)

# 3. Restart the application after updating environment variables
docker compose restart
# or
docker restart ai-chatbot

# 4. Check application logs for NextAuth configuration
docker logs ai-chatbot | grep -i auth
```

**Important Notes**:
- The `NEXTAUTH_URL` must exactly match the URL you use to access the application
- For IP-based deployments, use `http://ip-address:port` (not https)
- The project already includes `trustHost: true` configuration for IP-based deployments
- Both `AUTH_SECRET` and `NEXTAUTH_SECRET` must be set with the same value

#### 6. Out of Disk Space

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

#### 6. Container Exits Immediately

**Symptoms**: Container starts then stops within seconds

**Solutions**:
```bash
# Check container logs
docker logs ai-chatbot

# Check for missing environment variables
docker compose config

# Verify environment file syntax
cat /app/.env.production | grep -v '^#' | grep -v '^$'

# Run container in interactive mode for debugging
docker compose run --rm app sh
```

#### 7. Health Check Failing

**Symptoms**: Container marked as unhealthy despite running

**Solutions**:
```bash
# Check health status
docker inspect ai-chatbot --format='{{.State.Health}}'

# Manually test the health endpoint
docker exec ai-chatbot node -e "require('http').get('http://localhost:3000/api/health', (r) => console.log(r.statusCode))"

# Check container network
docker inspect ai-chatbot --format='{{.NetworkSettings.Networks}}'

# Increase health check timeout in docker-compose.yml if needed
```

#### 8. Permission Denied Errors

**Symptoms**: Script execution fails with permission denied

**Solutions**:
```bash
# Verify script is executable
ls -la /app/deploy/tencent-cvm-deploy.sh

# Make script executable
chmod +x /app/deploy/tencent-cvm-deploy.sh

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
bash -x /app/deploy/tencent-cvm-deploy.sh

# Increase logging level
export LOG_FILE=/tmp/deploy-debug.log
bash -x /app/deploy/tencent-cvm-deploy.sh

# Capture all output
bash -x /app/deploy/tencent-cvm-deploy.sh 2>&1 | tee /tmp/deploy.log
```

## CI/CD Pipeline Integration

### CI Pipeline Expectations

The CI/CD pipeline uses a simplified local build approach:

#### File Paths
- Deployment script: `deploy/tencent-cvm-deploy.sh`
- Docker Compose: `docker-compose.yml`
- Dockerfile: `Dockerfile`
- Documentation: `docs/deployment/tencent-cvm.md`

#### Script Requirements
- Must be shell scripts (sh/bash compatible)
- Must pass `shellcheck` validation
- Must use `set -euo pipefail` for error handling
- Must be executable (chmod +x)
- Should support environment variable configuration
- Must log all operations for audit trail

#### Environment Variables
The deployment script uses these environment variables:

```bash
COMPOSE_DIR=/app
ENV_FILE=/app/.env.production
GIT_BRANCH=main
HEALTH_CHECK_TIMEOUT=60
HEALTH_CHECK_INTERVAL=5
```

#### Expected Script Exit Codes
- `0`: Successful deployment
- `1`: Any error condition (script exits with `error_exit`)
- Non-zero: Any unhandled error

#### Logging
All operations are logged to:
- Stdout for CI console output
- `/var/log/aigc-chatbot-deploy.log` on the server

### Deployment Process

The CI/CD pipeline follows these steps:

1. SSHes into CVM server
2. Runs deployment script which:
   - Pulls latest code from git
   - Builds Docker image locally
   - Restarts services with docker compose
   - Verifies container health
   - Prunes old images

```bash
ssh -i /path/to/key ubuntu@server-ip \
  "cd /app && \
   bash deploy/tencent-cvm-deploy.sh"
```

### Rollback Procedure

To rollback to a previous version:

```bash
# Navigate to application directory
cd /app

# Checkout previous version
git log --oneline -n 10  # View recent commits
git checkout <commit-hash>

# Rebuild and restart
docker compose build
docker compose up -d

# Verify rollback
docker ps
docker compose logs -f

# To return to latest:
git checkout main
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/)
- [Git Documentation](https://git-scm.com/doc)
- [Application README](../../README.md)

## Support and Questions

For issues or questions:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review service logs: `sudo journalctl -u aigc-chatbot.service`
3. Check container logs: `docker logs ai-chatbot`
4. Review deployment script logs: `/var/log/aigc-chatbot-deploy.log`
5. Contact the development team with:
   - Error messages and full logs
   - System information (OS version, Docker version, etc.)
   - Steps to reproduce the issue
