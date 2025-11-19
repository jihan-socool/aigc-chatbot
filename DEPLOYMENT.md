# Deployment Overview

This document provides a quick reference for deploying the AIGC Chatbot application. For detailed information, see [docs/deployment/tencent-cvm.md](docs/deployment/tencent-cvm.md).

## Quick Start

### 1. Prerequisites
- Docker and docker-compose installed
- Tencent CCR credentials configured
- PostgreSQL database (if not using managed service)
- Redis (optional, for resumable streaming)

### 2. Deployment Files

All deployment assets are located in the `deploy/` directory:

| File | Purpose |
|------|---------|
| `tencent-cvm-deploy.sh` | Main deployment script (handles image pull, docker-compose startup, health checks) |
| `aigc-chatbot.service` | systemd service unit for automatic restart and boot startup |
| `docker-compose.yml.example` | Example docker-compose configuration |
| `docker-compose.production.yml` | (Copy to `/opt/aigc-chatbot/` on server) |

### 3. Installation Steps

#### On Your CVM Server

```bash
# 1. Create application directory
sudo mkdir -p /opt/aigc-chatbot
cd /opt/aigc-chatbot

# 2. Clone or copy project files
git clone <repository-url> .
# or
scp -r deploy/ .env.production .gitignore <server>:/opt/aigc-chatbot/

# 3. Set permissions
chmod +x deploy/tencent-cvm-deploy.sh

# 4. Install systemd service
sudo cp deploy/aigc-chatbot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable aigc-chatbot.service

# 5. Create docker-compose.yml at /opt/aigc-chatbot/
cp deploy/docker-compose.yml.example docker-compose.yml

# 6. Configure environment
# Edit .env.production with your production settings

# 7. Start the service
sudo systemctl start aigc-chatbot.service

# 8. Check status
sudo systemctl status aigc-chatbot.service
docker logs aigc-chatbot
```

## Configuration Files

### Environment File (.env.production)

Place at `/opt/aigc-chatbot/.env.production`:

```bash
# Required variables
AUTH_SECRET=<your-random-secret>
AI_GATEWAY_API_KEY=<your-api-key>
OPENAI_API_URL=https://your-gateway/v1
OPENAI_CHAT_MODEL=your-model-id
POSTGRES_URL=postgresql://user:pass@host:5432/db
BLOB_READ_WRITE_TOKEN=<your-token>
```

See `.env.example` for complete configuration options.

### Docker Compose File (docker-compose.yml)

Place at `/opt/aigc-chatbot/docker-compose.yml`:

Use the template from `deploy/docker-compose.yml.example` and customize:
- Image registry and namespace
- Port mappings
- Volume mounts
- Database and Redis settings

## Deployment Script

The `tencent-cvm-deploy.sh` script:

1. **Validates Prerequisites**: Checks Docker, docker-compose, and environment files
2. **Logs into Registry**: Authenticates with Tencent CCR
3. **Pulls Image**: Downloads latest image from registry
4. **Starts Services**: Runs docker-compose with production environment
5. **Verifies Health**: Waits for container to be healthy
6. **Prunes Old Images**: Cleans up unused Docker images

### Usage

```bash
# Basic usage (uses default configuration)
./deploy/tencent-cvm-deploy.sh

# Custom configuration via environment variables
export REGISTRY_URL="ccr.ccs.tencentyun.com"
export NAMESPACE="your-namespace"
export IMAGE_TAG="v1.2.3"
./deploy/tencent-cvm-deploy.sh

# Debug mode (trace all commands)
bash -x ./deploy/tencent-cvm-deploy.sh

# View logs
cat /var/log/aigc-chatbot-deploy.log
```

## Service Management

### Start/Stop/Restart

```bash
# Start the service
sudo systemctl start aigc-chatbot.service

# Stop the service
sudo systemctl stop aigc-chatbot.service

# Restart the service
sudo systemctl restart aigc-chatbot.service

# Check status
sudo systemctl status aigc-chatbot.service

# Enable auto-start on boot
sudo systemctl enable aigc-chatbot.service

# Disable auto-start on boot
sudo systemctl disable aigc-chatbot.service
```

### View Logs

```bash
# View systemd service logs
sudo journalctl -u aigc-chatbot.service -f

# View container logs
docker logs -f aigc-chatbot

# View deployment script logs
tail -f /var/log/aigc-chatbot-deploy.log

# Show last 100 lines
docker logs --tail 100 aigc-chatbot
```

## Health Monitoring

### Check Container Status

```bash
# Is container running?
docker ps | grep aigc-chatbot

# Get container health
docker inspect aigc-chatbot --format='{{.State.Health.Status}}'

# Full container details
docker inspect aigc-chatbot

# Container statistics
docker stats aigc-chatbot
```

### Check Application Health

```bash
# Ping the application
curl -i http://localhost:3000

# Check API health endpoint
curl -i http://localhost:3000/api/health

# Port availability
netstat -tlnp | grep 3000
```

## Troubleshooting

### Service Won't Start

```bash
# Check error logs
sudo journalctl -u aigc-chatbot.service -n 50 -p err

# Test deployment script manually
cd /opt/aigc-chatbot
bash -x deploy/tencent-cvm-deploy.sh

# Check Docker daemon
sudo systemctl status docker
```

### Container Exits Immediately

```bash
# Check container logs
docker logs aigc-chatbot

# Check environment variables
docker inspect aigc-chatbot --format='{{json .Config.Env}}'

# Run with interactive shell for debugging
docker-compose run --rm aigc-chatbot sh
```

### Image Pull Fails

```bash
# Test registry login
docker login ccr.ccs.tencentyun.com

# Manual image pull
docker pull ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:latest

# Check network connectivity
ping ccr.ccs.tencentyun.com
nslookup ccr.ccs.tencentyun.com
```

## Maintenance

### Update Application

```bash
# Pull latest image
docker pull ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:latest

# Restart service to use new image
sudo systemctl restart aigc-chatbot.service

# Or run deployment script directly
cd /opt/aigc-chatbot && bash deploy/tencent-cvm-deploy.sh
```

### Rollback to Previous Version

```bash
# Stop current service
sudo systemctl stop aigc-chatbot.service

# Pull specific version
docker pull ccr.ccs.tencentyun.com/YOUR_NAMESPACE/aigc-chatbot:v1.2.2

# Update image tag in docker-compose.yml
sed -i 's/latest/v1.2.2/g' docker-compose.yml

# Restart service
sudo systemctl start aigc-chatbot.service
```

### Clean Up Old Images

```bash
# Remove dangling images
docker image prune -f

# Remove all unused images
docker image prune -a -f

# View image sizes
docker images --format "table {{.Repository}}\t{{.Size}}"
```

## CI/CD Integration

The deployment scripts are designed to work with CI/CD pipelines:

```bash
# Example CI/CD deployment command
ssh -i /path/to/key ubuntu@server-ip << 'EOF'
  cd /opt/aigc-chatbot
  export REGISTRY_USERNAME=$CI_REGISTRY_USERNAME
  export REGISTRY_PASSWORD=$CI_REGISTRY_PASSWORD
  export IMAGE_TAG=$CI_COMMIT_SHA
  bash deploy/tencent-cvm-deploy.sh
EOF
```

For details on CI/CD integration, see [CI/CD Pipeline Integration](docs/deployment/tencent-cvm.md#cicd-pipeline-integration) section.

## Documentation

- [Full Deployment Guide](docs/deployment/tencent-cvm.md)
- [Application README](README.md)
- [Docker Documentation](https://docs.docker.com/)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/)

## Support

For issues or questions:

1. Check deployment logs: `/var/log/aigc-chatbot-deploy.log`
2. Check systemd logs: `sudo journalctl -u aigc-chatbot.service`
3. Check container logs: `docker logs aigc-chatbot`
4. Review [Full Troubleshooting Guide](docs/deployment/tencent-cvm.md#troubleshooting)
