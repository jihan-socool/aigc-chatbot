# GitHub Actions Deployment Setup Instructions

## Overview

This repository now includes a complete CI/CD pipeline for automatic deployment to Tencent Cloud infrastructure (CCR for container images, CVM for application hosting).

## Files Created

### CI/CD Pipeline
- **`.github/workflows/deploy.yml`** - Main GitHub Actions workflow
  - Triggered on pushes to `main` branch or manual dispatch
  - Builds Docker image, pushes to Tencent CCR, and deploys to CVM
  - Well-documented with all required secrets listed

### Docker & Deployment
- **`Dockerfile`** - Multi-stage Docker build configuration
  - Builder stage: compiles Next.js application
  - Runtime stage: minimal production image
  - Includes health check endpoint
- **`docker-compose.yml`** - Service orchestration configuration
  - Defines the application container setup
  - Port mapping, environment variables, logging
  - Health checks and proper networking
- **`.dockerignore`** - Optimizes Docker build context

### Deployment Automation
- **`scripts/deploy.sh`** - Remote deployment script executed on CVM
  - Validates Docker/Docker Compose availability
  - Pulls latest image from CCR
  - Gracefully stops old containers
  - Starts new containers with health verification

### Documentation
- **`.github/DEPLOYMENT.md`** - Comprehensive deployment guide
  - Workflow overview and triggers
  - Required secrets documentation
  - Local setup instructions for CVM
  - Troubleshooting guide
  - Security best practices
  - Rollback procedures
- **`.github/SETUP_INSTRUCTIONS.md`** - This file

## Quick Start

### 1. Configure GitHub Repository Secrets

Go to your GitHub repository → Settings → Secrets and Variables → Actions

Add the following secrets:

**Tencent CCR Credentials:**
```
CCR_REGISTRY          # e.g., ccr.ccs.tencentyun.com
CCR_NAMESPACE         # Your CCR namespace
CCR_REPOSITORY        # Repository name
CCR_USERNAME          # Login username
CCR_PASSWORD          # Login password/token
```

**Tencent CVM SSH Credentials:**
```
DEPLOY_SSH_HOST       # CVM IP or hostname
DEPLOY_SSH_USER       # SSH user (usually root)
DEPLOY_SSH_PORT       # SSH port (usually 22)
DEPLOY_SSH_KEY        # Private SSH key (PEM format, no passphrase)
```

**Optional - Docker Mirror (for faster builds in China):**
```
DOCKER_HUB_MIRROR     # e.g., mirror.ccs.tencentyun.com
```

### 2. Prepare Your Tencent CVM

SSH into your CVM and prepare the deployment environment:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create application directory
sudo mkdir -p /app
cd /app

# Create .env.production with your environment variables
sudo cat > .env.production << 'EOF'
DATABASE_URL=postgresql://user:pass@db:5432/dbname
NODE_ENV=production
# Add other environment variables as needed
EOF
```

### 3. Test the Workflow

Push to the main branch:

```bash
git add .
git commit -m "Add CI/CD pipeline"
git push origin main
```

Monitor the workflow in GitHub Actions tab. After successful build and push to CCR, the deployment to CVM will run automatically.

## Workflow Execution Flow

```
Code Push to Main
        ↓
Checkout Code
        ↓
Setup Node.js & pnpm
        ↓
Setup Docker Buildx
        ↓
Login to Tencent CCR
        ↓
Build & Push Docker Image
        ↓
     Success? ──No──→ [STOP]
        ↓ Yes
SSH into CVM
        ↓
Login to CCR Registry
        ↓
Pull Latest Image
        ↓
Stop Old Containers
        ↓
Start New Containers
        ↓
Verify Deployment
        ↓
Complete ✓
```

## Key Features

✅ **Automatic Deployments**: Every push to main triggers the pipeline
✅ **Version Control**: Image tagged with commit SHA and 'latest'
✅ **Health Checks**: Built-in health monitoring
✅ **Graceful Rollouts**: Removes old containers cleanly
✅ **Secure**: Uses GitHub Secrets for credentials
✅ **Documented**: Comprehensive guides and in-workflow documentation
✅ **Caching**: Speeds up builds with layer caching
✅ **Error Handling**: Deployment only on successful build/push

## Monitoring & Troubleshooting

### View Workflow Logs
1. Go to GitHub repository → Actions tab
2. Click on the workflow run
3. View step-by-step logs

### Check Application Logs on CVM
```bash
ssh user@host
cd /app
docker-compose logs -f        # Follow application logs
docker-compose ps             # Check container status
```

### Common Issues

See **`.github/DEPLOYMENT.md`** for detailed troubleshooting, including:
- Image pull failures
- Container startup issues
- SSH connection problems
- Network connectivity

## Security Considerations

⚠️ **Important Security Notes:**

1. **SSH Key**: Use a deployment-specific key without a passphrase
2. **Credentials**: Never commit `.env` files or secrets to the repository
3. **Registry Access**: Limit CCR permissions to necessary scopes
4. **Key Rotation**: Regularly rotate SSH keys and credentials
5. **Audit Logs**: Monitor GitHub Actions execution logs for security issues

## Manual Deployment

If needed, you can manually trigger a workflow run:

1. Go to GitHub repository → Actions tab
2. Select "Build and Deploy to Tencent CCR" workflow
3. Click "Run workflow" button
4. Choose branch and click "Run workflow"

## Disabling Auto-Deployment

To temporarily disable automatic deployments:

1. Go to GitHub repository → Settings → Actions
2. Disable the workflow or the repository

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)
- [Tencent CCR Guide](https://cloud.tencent.com/document/product/1141)
- [Tencent CVM Documentation](https://cloud.tencent.com/document/product/213)

## Support

For issues or questions:
1. Check `.github/DEPLOYMENT.md` for detailed guides
2. Review GitHub Actions logs for specific errors
3. Check SSH connectivity and permissions on CVM
4. Verify all required secrets are configured correctly
