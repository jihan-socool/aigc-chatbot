# Scripts Directory

This directory contains helper scripts for deployment, configuration, and maintenance of the application.

## Deployment Scripts

### `deploy.sh`
**Location**: Called remotely by GitHub Actions on the CVM  
**Purpose**: Orchestrates the deployment process on the Tencent CVM

**Usage**:
```bash
# Typically called automatically by GitHub Actions
cd /app && bash deploy.sh
```

**What it does**:
1. Validates Docker and Docker Compose are installed
2. Pulls the latest images from CCR
3. Stops and removes old containers
4. Starts new containers
5. Verifies deployment success
6. Logs all actions to `/app/deploy.log`

## Setup Scripts

### `setup-cvm.sh`
**Location**: Run once on a fresh CVM to prepare it for deployment  
**Purpose**: Complete CVM setup with Docker, Docker Compose, and application directory

**Usage**:
```bash
# On your CVM (requires root)
sudo bash setup-cvm.sh
```

**What it does**:
1. Updates system packages
2. Installs required dependencies (curl, git, jq, etc.)
3. Installs Docker (if not present)
4. Installs Docker Compose (latest version)
5. Configures Docker daemon with registry mirrors
6. Creates `/app` directory structure
7. Creates docker-compose.yml and environment templates
8. Optionally logs in to CCR

**Interactive prompts**:
- CCR registry URL
- CCR namespace
- CCR repository name

### `configure-docker-daemon.sh`
**Location**: Run on CVM to configure Docker daemon settings  
**Purpose**: Configure Docker registry mirrors and logging settings

**Usage**:
```bash
# On your CVM (requires root)
sudo bash configure-docker-daemon.sh [mirror-url]

# Examples:
sudo bash configure-docker-daemon.sh mirror.ccs.tencentyun.com
sudo bash configure-docker-daemon.sh docker.mirrors.ustc.edu.cn
```

**What it does**:
1. Backs up existing `/etc/docker/daemon.json`
2. Configures registry mirrors for faster image pulls
3. Sets up log rotation (10MB × 3 files)
4. Enables live-restore and optimizes proxy settings
5. Validates JSON configuration
6. Reloads and restarts Docker daemon
7. Verifies registry mirrors are active

**Configuration applied**:
```json
{
  "registry-mirrors": ["https://mirror.ccs.tencentyun.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}
```

## Validation Scripts

### `validate-secrets.sh`
**Location**: Run locally to verify GitHub Actions secrets configuration  
**Purpose**: Provides checklist and guidance for configuring all required secrets

**Usage**:
```bash
# Run from repository root
bash scripts/validate-secrets.sh
```

**What it displays**:
1. List of all required GitHub secrets
2. Description of each secret
3. Example values
4. Validation checklist
5. Manual testing commands
6. Common errors and solutions

**Required secrets checked**:
- `CCR_REGISTRY`, `CCR_NAMESPACE`, `CCR_REPOSITORY`
- `CCR_USERNAME`, `CCR_PASSWORD`
- `DEPLOY_SSH_HOST`, `DEPLOY_SSH_USER`, `DEPLOY_SSH_PORT`, `DEPLOY_SSH_KEY`
- `DOCKER_HUB_MIRROR` (optional)

## Maintenance Scripts

### `clear-user.ts`
**Location**: Run locally with Node.js/TypeScript  
**Purpose**: Remove a user and all associated data from the database

**Usage**:
```bash
# From repository root
pnpm tsx scripts/clear-user.ts <username>
```

**What it does**:
1. Connects to the database
2. Deletes user's chat history
3. Deletes user account
4. Handles related data cleanup

⚠️ **Warning**: This operation is destructive and cannot be undone.

## Quick Start Guide

### For Initial CVM Setup

1. **Prepare CVM** (run once per server):
   ```bash
   # SSH into your CVM
   ssh user@your-cvm-ip
   
   # Download and run setup script
   curl -O https://raw.githubusercontent.com/your-repo/main/scripts/setup-cvm.sh
   sudo bash setup-cvm.sh
   ```

2. **Configure Docker daemon** (optional, if not using setup-cvm.sh):
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/main/scripts/configure-docker-daemon.sh
   sudo bash configure-docker-daemon.sh mirror.ccs.tencentyun.com
   ```

3. **Configure environment**:
   ```bash
   cd /app
   sudo nano .env.production  # Edit with your values
   ```

4. **Add SSH key**:
   ```bash
   # Generate key locally
   ssh-keygen -t ed25519 -f github-deploy -N ""
   
   # Copy public key to CVM
   ssh-copy-id -i github-deploy.pub user@your-cvm-ip
   
   # Add private key to GitHub Secrets as DEPLOY_SSH_KEY
   ```

### For GitHub Configuration

1. **Validate setup**:
   ```bash
   # Run from repository root
   bash scripts/validate-secrets.sh
   ```

2. **Follow checklist** in the output to configure all secrets

3. **See detailed guide**: `.github/CCR_SETUP_GUIDE.md`

## Script Dependencies

All scripts use bash and standard Unix utilities. Additional dependencies:

- `setup-cvm.sh`: curl, git, jq (installed automatically)
- `configure-docker-daemon.sh`: python3 or jq (for JSON validation)
- `validate-secrets.sh`: None
- `deploy.sh`: docker, docker-compose (required on CVM)
- `clear-user.ts`: Node.js, pnpm, tsx (development environment)

## Environment Variables

Scripts respect the following environment variables:

- `APP_DIR`: Application directory (default: `/app`)
- `DOCKER_MIRROR`: Docker Hub mirror URL (default: `mirror.ccs.tencentyun.com`)

## Logging

Deployment logs are saved to `/app/deploy.log` on the CVM with timestamps:

```bash
# View deployment logs
tail -f /app/deploy.log

# View recent deployments
tail -100 /app/deploy.log
```

## Troubleshooting

### Scripts fail with "Permission denied"

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### Docker daemon configuration fails

```bash
# Restore backup
sudo cp /etc/docker/daemon.json.backup /etc/docker/daemon.json
sudo systemctl restart docker
```

### SSH connection fails during deployment

```bash
# Test SSH connection manually
ssh -i /path/to/key user@host -p port

# Check authorized_keys on CVM
cat ~/.ssh/authorized_keys
```

### Deployment fails after successful push

```bash
# SSH into CVM and check logs
ssh user@host
cd /app
docker-compose logs -f

# Check deployment log
cat /app/deploy.log
```

## Security Notes

⚠️ **Important**:

1. **Never commit** `.env` or `.env.production` files
2. **Restrict permissions** on environment files: `chmod 600 .env.production`
3. **Use SSH keys without passphrases** for CI/CD (store securely in GitHub Secrets)
4. **Rotate credentials regularly** (every 90 days recommended)
5. **Limit SSH access** to deployment user only
6. **Review logs** regularly for suspicious activity

## Additional Resources

- [CCR Setup Guide](../.github/CCR_SETUP_GUIDE.md) - Complete CCR configuration guide
- [Deployment Guide](../.github/DEPLOYMENT.md) - CI/CD workflow documentation  
- [Setup Instructions](../.github/SETUP_INSTRUCTIONS.md) - Quick start guide

## Support

For issues with scripts:

1. Check script output for specific error messages
2. Review logs in `/app/deploy.log` on CVM
3. Verify all prerequisites are met
4. Test each component individually
5. See troubleshooting sections in documentation

## Contributing

When adding new scripts:

1. Use `#!/usr/bin/env bash` shebang
2. Include `set -euo pipefail` for error handling
3. Add colored output for better UX
4. Include helpful error messages
5. Document in this README
6. Make executable: `chmod +x script.sh`
