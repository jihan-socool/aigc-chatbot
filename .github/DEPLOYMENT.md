# Deployment Guide

This document describes the CI/CD pipeline for building and deploying the application to Tencent Cloud (CCR and CVM).

## Overview

The GitHub Actions workflow (`workflows/deploy.yml`) automates the following:

1. **Code Checkout**: Clones the repository
2. **Build Environment Setup**: Enables pnpm and caches dependencies
3. **Docker Build & Push**: Builds the application and pushes to Tencent CCR
4. **Remote Deployment**: SSHes into the Tencent CVM and orchestrates the deployment

## Workflow Triggers

- **Push to main branch**: Automatically triggers when code is pushed to the `main` branch
- **Manual Dispatch**: Can be manually triggered from GitHub Actions UI

## Required GitHub Secrets

The following secrets must be configured in your GitHub repository settings:

### Tencent CCR (Container Cloud Registry)
- `CCR_REGISTRY`: Registry host (e.g., `ccr.ccs.tencentyun.com`)
- `CCR_NAMESPACE`: CCR namespace/project name
- `CCR_REPOSITORY`: CCR repository name
- `CCR_USERNAME`: CCR authentication username
- `CCR_PASSWORD`: CCR authentication password or API token

### Tencent CVM (Cloud Virtual Machine)
- `DEPLOY_SSH_HOST`: Target CVM IP address or domain name
- `DEPLOY_SSH_USER`: SSH username (typically `root` or a deployment user)
- `DEPLOY_SSH_PORT`: SSH port (default: `22`)
- `DEPLOY_SSH_KEY`: Private SSH key for authentication (PEM format without passphrase)

### Docker Configuration (Optional)
- `DOCKER_HUB_MIRROR`: Docker Hub mirror URL for faster builds in China region
  - Example: `mirror.ccs.tencentyun.com`

## Workflow Steps

### 1. Checkout
Clones the repository code using GitHub's checkout action.

### 2. Setup Node.js & pnpm
- Enables corepack for pnpm management
- Installs the specified pnpm version (9.12.3)
- Uses GitHub Actions cache for faster dependency resolution

### 3. Docker Setup
- Sets up Docker Buildx for multi-platform builds
- Optionally configures a Docker Hub mirror for China regions
- Logs in to Tencent CCR registry

### 4. Build & Push
- Builds the Docker image using `docker/build-push-action`
- Tags the image with:
  - Commit SHA (short form): `registry/namespace/repository:abc1234`
  - Latest tag: `registry/namespace/repository:latest`
- Uses GitHub Actions cache for Docker layers

### 5. Deploy to CVM
- Only runs if the previous step succeeds (`if: success()`)
- Connects via SSH to the Tencent CVM
- Logs in to CCR registry on the remote machine
- Executes `docker-compose pull` to fetch the latest image
- Runs `docker-compose up -d --remove-orphans` to deploy

## Local Setup for Deployment

### CVM Prerequisites

Ensure the following are installed on your Tencent CVM:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Application Directory

Create the application directory and docker-compose.yml:

```bash
sudo mkdir -p /app
cd /app

# Copy docker-compose.yml from repository
# Create .env.production file with necessary environment variables
```

### Environment File

Create `/app/.env.production` with your production settings:

```env
DATABASE_URL=postgresql://user:password@db:5432/dbname
REDIS_URL=redis://redis:6379
# Add other environment variables as needed
```

## Dockerfile

The application uses a multi-stage Dockerfile:

- **Builder stage**: Installs all dependencies and builds the Next.js application
- **Runtime stage**: Creates a minimal image with only production dependencies

Key features:
- Alpine Linux base for minimal image size
- pnpm for efficient dependency management
- Health check endpoint at `http://localhost:3000`
- Proper production build optimization

## Docker Compose

The `docker-compose.yml` orchestrates:

- **Service Configuration**: Runs the application container
- **Port Mapping**: Maps port 3000 to the host
- **Environment**: Loads production settings from `.env.production`
- **Health Check**: Monitors application health
- **Logging**: Configures log rotation to prevent disk space issues
- **Networking**: Uses a custom network for inter-service communication

## Deployment Script

The `scripts/deploy.sh` script is called on the remote CVM via the GitHub Actions workflow:

1. Validates prerequisites (Docker, Docker Compose)
2. Pulls the latest image from CCR
3. Stops and removes old containers
4. Starts new containers with the latest image
5. Verifies successful deployment

### Manual Execution

To manually run the deployment script on the CVM:

```bash
ssh -i your-key.pem user@host
cd /app
bash /path/to/deploy.sh
```

## Monitoring and Troubleshooting

### View Deployment Logs

1. **GitHub Actions**: View logs in the repository's "Actions" tab
2. **Remote Server**: Check `/app/deploy.log` for deployment history
3. **Docker Logs**: Run `docker-compose logs -f` on the CVM

### Common Issues

**Image Pull Fails**
- Verify CCR credentials are correct
- Check network connectivity from CVM to CCR
- Ensure the image exists in the CCR registry

**Container Fails to Start**
- Check `.env.production` is properly configured
- Review application logs: `docker-compose logs app`
- Verify required services (database, cache) are accessible

**SSH Connection Issues**
- Verify the SSH key is configured correctly (no passphrase)
- Check firewall rules allow SSH (port 22 by default)
- Ensure `DEPLOY_SSH_USER` has sufficient permissions

## Security Best Practices

1. **SSH Key Management**
   - Use a deployment-specific SSH key, not your personal key
   - Store the key securely as a GitHub Secret
   - Regularly rotate keys

2. **Credentials**
   - Use GitHub Secrets for all sensitive data
   - Never commit `.env` files or credentials to the repository
   - Use separate credentials for development and production

3. **Docker Registry Access**
   - Limit CCR access to necessary teams/projects
   - Use automation-specific service accounts when available
   - Monitor registry access logs

## Rollback Procedure

To roll back to a previous deployment:

1. On the CVM, check available image tags:
   ```bash
   docker image ls
   ```

2. Update `docker-compose.yml` to use the previous image tag

3. Redeploy:
   ```bash
   docker-compose pull
   docker-compose up -d --remove-orphans
   ```

## Additional Resources

- [Tencent CCR Documentation](https://cloud.tencent.com/document/product/1141)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
