# Tencent Cloud Container Registry (CCR) Setup Guide

This guide walks through the complete setup of Tencent Cloud Container Registry (CCR) credentials for the CI/CD pipeline.

## Prerequisites

- A Tencent Cloud account with CCR access
- A Tencent Cloud CVM instance for deployment
- GitHub repository with admin access
- Basic familiarity with Docker and SSH

## Step 1: Create CCR Namespace and Repository

### 1.1 Login to Tencent Cloud Console

1. Navigate to [Tencent Cloud Console](https://console.cloud.tencent.com/)
2. Go to **Products** → **Container Service** → **Container Registry (CCR)**

### 1.2 Create a Namespace

1. Click on **Namespace Management** in the left sidebar
2. Click **Create Namespace**
3. Fill in the namespace details:
   - **Name**: Choose a unique name (e.g., `my-company`, `ai-chatbot`)
   - **Region**: Select the region closest to your CVM (e.g., `ap-guangzhou`, `ap-shanghai`)
   - **Access Level**: Choose `Private` for production applications
4. Click **Confirm**
5. **Save the namespace name** - you'll need it for GitHub secrets

### 1.3 Create a Repository

1. Click on **Image Repository** in the left sidebar
2. Click **Create**
3. Fill in the repository details:
   - **Namespace**: Select the namespace you just created
   - **Name**: Choose a repository name (e.g., `ai-chatbot`, `app`)
   - **Type**: Select `Private`
   - **Description**: Optional description
4. Click **Confirm**
5. **Save the repository name** - you'll need it for GitHub secrets

### 1.4 Get Registry Information

After creating the repository, note down:
- **Registry URL**: Usually `ccr.ccs.tencentyun.com` or your region-specific URL
- **Full Image Path**: `ccr.ccs.tencentyun.com/your-namespace/your-repository`

## Step 2: Generate CCR Access Credentials

### 2.1 Create Long-Term Access Token

1. In the CCR console, click your username in the top-right corner
2. Go to **Access Management** → **Access Key** → **API Keys**
3. Click **Create Key** or use an existing one
4. **Save both `SecretId` and `SecretKey`** - these are your CCR credentials:
   - `SecretId` = CCR_USERNAME
   - `SecretKey` = CCR_PASSWORD

⚠️ **Important**: Store these credentials securely. The `SecretKey` is only shown once!

### Alternative: Use Instance RAM Role (Recommended for Production)

For enhanced security, you can configure your CVM with a RAM role that has CCR access:
1. Go to **CAM (Cloud Access Management)**
2. Create a service role for CVM
3. Attach the `QcloudCCRFullAccess` policy
4. Assign the role to your CVM instance

## Step 3: Configure Docker Hub Mirror (Optional but Recommended)

Docker Hub mirrors significantly improve build speeds in China regions.

### 3.1 Get Tencent Cloud Docker Hub Mirror URL

Common Tencent Cloud Docker Hub mirrors:
- `mirror.ccs.tencentyun.com`
- `docker.mirrors.ustc.edu.cn`
- `hub-mirror.c.163.com`

### 3.2 Configure on CVM Server

SSH into your CVM and run the helper script (see Step 5) or manually configure:

```bash
# Create or edit Docker daemon configuration
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://mirror.ccs.tencentyun.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# Restart Docker to apply changes
sudo systemctl daemon-reload
sudo systemctl restart docker

# Verify configuration
docker info | grep -A 5 "Registry Mirrors"
```

## Step 4: Configure GitHub Secrets

### 4.1 Access GitHub Repository Settings

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

### 4.2 Add Required Secrets

Add each of the following secrets by clicking **New repository secret** for each:

#### CCR Registry Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `CCR_REGISTRY` | CCR registry host | `ccr.ccs.tencentyun.com` |
| `CCR_NAMESPACE` | Your CCR namespace | `my-company` |
| `CCR_REPOSITORY` | Your repository name | `ai-chatbot` |
| `CCR_USERNAME` | Tencent Cloud SecretId | `AKID...` |
| `CCR_PASSWORD` | Tencent Cloud SecretKey | `xxx...` |

#### CVM Deployment Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `DEPLOY_SSH_HOST` | CVM public IP or domain | `123.45.67.89` |
| `DEPLOY_SSH_USER` | SSH username | `root` or `ubuntu` |
| `DEPLOY_SSH_PORT` | SSH port | `22` |
| `DEPLOY_SSH_KEY` | Private SSH key (PEM format) | See below |

#### Optional Secrets

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `DOCKER_HUB_MIRROR` | Docker Hub mirror URL | `mirror.ccs.tencentyun.com` |

### 4.3 Generate and Add SSH Key

If you don't have an SSH key for deployment:

```bash
# Generate a new SSH key pair (without passphrase)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f github-actions-deploy -N ""

# This creates two files:
# - github-actions-deploy (private key) - add this to GitHub secrets
# - github-actions-deploy.pub (public key) - add this to CVM

# View the private key (add this as DEPLOY_SSH_KEY secret)
cat github-actions-deploy

# View the public key (add this to CVM's authorized_keys)
cat github-actions-deploy.pub
```

Add the private key to GitHub:
1. Copy the entire content of the private key file (including `-----BEGIN` and `-----END` lines)
2. In GitHub, create a new secret named `DEPLOY_SSH_KEY`
3. Paste the private key content

Add the public key to CVM:
```bash
# SSH into your CVM
ssh user@your-cvm-ip

# Add the public key to authorized_keys
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "your-public-key-content" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Step 5: Configure CVM Server

### 5.1 Install Docker and Docker Compose

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker-compose --version
```

### 5.2 Setup Application Directory

```bash
# Create application directory
sudo mkdir -p /app
cd /app

# Copy docker-compose.yml from the repository
# You can manually create it or it will be deployed via SSH
```

### 5.3 Configure Docker Daemon (with helper script)

The repository includes a helper script to configure Docker daemon settings. Upload it to your CVM:

```bash
# From your local machine, copy the script to CVM
scp scripts/configure-docker-daemon.sh user@your-cvm-ip:/tmp/

# SSH into CVM and run the script
ssh user@your-cvm-ip
sudo bash /tmp/configure-docker-daemon.sh mirror.ccs.tencentyun.com
```

### 5.4 Setup CCR Credentials on CVM

Login to CCR from your CVM to cache credentials:

```bash
# Login to Tencent CCR
docker login ccr.ccs.tencentyun.com
# Enter your CCR_USERNAME (SecretId)
# Enter your CCR_PASSWORD (SecretKey)

# Verify login
docker info | grep "Registry:"
```

### 5.5 Create Environment File

Create `/app/.env.production` with your production environment variables:

```bash
cd /app
sudo tee .env.production > /dev/null <<EOF
# Database Configuration
DATABASE_URL=postgresql://user:password@your-db-host:5432/dbname

# Redis Configuration (if using)
REDIS_URL=redis://your-redis-host:6379

# Application Settings
NODE_ENV=production
PORT=3000

# Auth Configuration (if using NextAuth)
NEXTAUTH_URL=https://yourdomain.com
NEXTAUTH_SECRET=your-random-secret-key

# AI Provider Configuration
OPENAI_API_KEY=your-openai-key

# Add other environment variables as needed
EOF

# Secure the environment file
sudo chmod 600 .env.production
```

### 5.6 Copy Docker Compose File

Create `/app/docker-compose.yml`:

```bash
cd /app
sudo tee docker-compose.yml > /dev/null <<'EOF'
version: '3.8'

services:
  app:
    image: ${CCR_REGISTRY}/${CCR_NAMESPACE}/${CCR_REPOSITORY}:latest
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
EOF
```

Also create an `.env` file to set the image variables:

```bash
cd /app
sudo tee .env > /dev/null <<EOF
CCR_REGISTRY=ccr.ccs.tencentyun.com
CCR_NAMESPACE=your-namespace
CCR_REPOSITORY=your-repository
EOF
```

## Step 6: Test the Setup

### 6.1 Test Docker Login

```bash
# On your CVM
docker login ccr.ccs.tencentyun.com -u YOUR_SECRET_ID -p YOUR_SECRET_KEY
```

### 6.2 Test GitHub Actions Workflow

1. Push a commit to the `main` branch
2. Go to your GitHub repository → **Actions** tab
3. Watch the workflow execution
4. Verify each step completes successfully:
   - ✓ Checkout code
   - ✓ Setup pnpm and Node.js
   - ✓ Login to CCR
   - ✓ Build and push Docker image
   - ✓ Deploy to CVM

### 6.3 Verify Deployment on CVM

```bash
# SSH into your CVM
ssh user@your-cvm-ip

# Check running containers
docker ps

# Check application logs
docker logs ai-chatbot

# Test the application
curl http://localhost:3000
```

## Troubleshooting

### Issue: CCR Login Failed

**Symptoms**: `Error response from daemon: Get https://ccr.ccs.tencentyun.com/v2/: unauthorized`

**Solutions**:
1. Verify your CCR_USERNAME (SecretId) and CCR_PASSWORD (SecretKey) are correct
2. Check that the credentials have CCR access permissions
3. Ensure the namespace and repository exist
4. Try regenerating API keys in the Tencent Cloud console

### Issue: SSH Connection Failed

**Symptoms**: `Permission denied (publickey)` or `Connection refused`

**Solutions**:
1. Verify the SSH key is correctly formatted (includes `-----BEGIN` and `-----END` lines)
2. Ensure the public key is in `~/.ssh/authorized_keys` on the CVM
3. Check SSH port is correct (default is 22)
4. Verify CVM firewall allows SSH connections
5. Test SSH connection manually: `ssh -i your-key.pem user@host`

### Issue: Docker Pull Failed

**Symptoms**: `Error response from daemon: pull access denied`

**Solutions**:
1. Login to CCR on the CVM: `docker login ccr.ccs.tencentyun.com`
2. Verify the image exists in CCR
3. Check namespace and repository names are correct
4. Ensure credentials have pull permissions

### Issue: Container Won't Start

**Symptoms**: Container exits immediately or health check fails

**Solutions**:
1. Check container logs: `docker logs ai-chatbot`
2. Verify `.env.production` file exists and has correct values
3. Check database connectivity from CVM
4. Verify all required environment variables are set
5. Check port 3000 is not already in use: `netstat -tuln | grep 3000`

### Issue: Docker Hub Mirror Not Working

**Symptoms**: Slow image pulls, timeout errors

**Solutions**:
1. Verify `/etc/docker/daemon.json` is correctly formatted (valid JSON)
2. Restart Docker daemon: `sudo systemctl restart docker`
3. Test mirror connectivity: `curl https://mirror.ccs.tencentyun.com`
4. Try alternative mirrors if one is not working

## Security Best Practices

### 1. Credential Management
- ✅ Use GitHub Secrets for all sensitive data
- ✅ Never commit credentials to the repository
- ✅ Rotate API keys and SSH keys regularly (every 90 days)
- ✅ Use separate credentials for different environments

### 2. SSH Key Security
- ✅ Generate deployment-specific SSH keys
- ✅ Never use personal SSH keys for CI/CD
- ✅ Use Ed25519 keys (more secure than RSA)
- ✅ Never add passphrase to CI/CD SSH keys
- ✅ Restrict SSH key permissions on CVM (600 for private keys)

### 3. Network Security
- ✅ Use private CCR repositories for production
- ✅ Restrict CVM security group to allow only necessary ports
- ✅ Use HTTPS for all external communications
- ✅ Enable CVM firewall and fail2ban for SSH protection

### 4. Docker Security
- ✅ Use non-root user in Docker containers
- ✅ Enable Docker content trust
- ✅ Regularly update base images
- ✅ Scan images for vulnerabilities
- ✅ Limit container resources (CPU, memory)

### 5. Monitoring and Auditing
- ✅ Monitor GitHub Actions workflow executions
- ✅ Review CVM SSH access logs regularly
- ✅ Enable Tencent Cloud audit logs
- ✅ Set up alerts for failed deployments
- ✅ Monitor container resource usage

## Next Steps

After completing this setup:

1. **Test the Pipeline**: Make a small code change and push to verify the entire CI/CD pipeline works
2. **Setup Monitoring**: Configure health checks and monitoring for your application
3. **Configure Domain**: Point your domain to the CVM IP and set up SSL/TLS
4. **Setup Backups**: Configure regular backups for your database and application data
5. **Document Custom Settings**: Document any project-specific configurations in your repository

## Additional Resources

- [Tencent CCR Official Documentation](https://cloud.tencent.com/document/product/1141)
- [Tencent CVM Documentation](https://cloud.tencent.com/document/product/213)
- [GitHub Actions Secrets Guide](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [SSH Key Management](https://www.ssh.com/academy/ssh/keygen)

## Quick Reference: All Required Secrets

```bash
# CCR Configuration
CCR_REGISTRY=ccr.ccs.tencentyun.com
CCR_NAMESPACE=<your-namespace>
CCR_REPOSITORY=<your-repository>
CCR_USERNAME=<tencent-secret-id>
CCR_PASSWORD=<tencent-secret-key>

# CVM Configuration
DEPLOY_SSH_HOST=<cvm-ip-or-domain>
DEPLOY_SSH_USER=<ssh-username>
DEPLOY_SSH_PORT=22
DEPLOY_SSH_KEY=<private-ssh-key-content>

# Optional
DOCKER_HUB_MIRROR=mirror.ccs.tencentyun.com
```

## Support

If you encounter issues not covered in this guide:

1. Check `.github/DEPLOYMENT.md` for deployment workflow details
2. Review GitHub Actions workflow logs
3. Check CVM system logs: `/var/log/syslog` or `journalctl -xe`
4. Verify all prerequisites are met
5. Test each component individually (SSH, Docker, CCR login)
