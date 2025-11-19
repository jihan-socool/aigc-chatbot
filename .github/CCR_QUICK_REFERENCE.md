# CCR Configuration Quick Reference

Quick reference card for setting up Tencent Cloud Container Registry (CCR) credentials.

## 🚀 Quick Setup (5 Steps)

### 1️⃣ Create CCR Resources in Tencent Cloud

Login to [Tencent Cloud Console](https://console.cloud.tencent.com/) → Container Registry (CCR):

```
Create Namespace → Enter name → Set to Private → Confirm
Create Repository → Select namespace → Enter name → Set to Private → Confirm
```

**Note down**:
- Registry URL: `ccr.ccs.tencentyun.com`
- Namespace: `your-namespace`
- Repository: `your-repository`

### 2️⃣ Generate Access Credentials

Tencent Cloud Console → Username (top-right) → Access Management → API Keys:

```
Create Key or use existing
```

**Note down**:
- SecretId (CCR_USERNAME)
- SecretKey (CCR_PASSWORD)

### 3️⃣ Setup CVM Server

```bash
# SSH into your CVM
ssh user@your-cvm-ip

# Run setup script (installs Docker, Docker Compose, configures everything)
curl -fsSL https://raw.githubusercontent.com/your-repo/main/scripts/setup-cvm.sh | sudo bash
```

### 4️⃣ Generate and Configure SSH Key

```bash
# On your local machine
ssh-keygen -t ed25519 -C "github-deploy" -f github-deploy -N ""

# Copy public key to CVM
ssh-copy-id -i github-deploy.pub user@your-cvm-ip

# Private key content goes to GitHub Secret DEPLOY_SSH_KEY
cat github-deploy
```

### 5️⃣ Configure GitHub Secrets

GitHub repo → Settings → Secrets and variables → Actions → New repository secret:

| Secret Name | Value | Where to Get |
|-------------|-------|--------------|
| `CCR_REGISTRY` | `ccr.ccs.tencentyun.com` | Fixed value |
| `CCR_NAMESPACE` | `your-namespace` | From Step 1 |
| `CCR_REPOSITORY` | `your-repository` | From Step 1 |
| `CCR_USERNAME` | `AKID...` | From Step 2 (SecretId) |
| `CCR_PASSWORD` | `xxx...` | From Step 2 (SecretKey) |
| `DEPLOY_SSH_HOST` | `123.45.67.89` | Your CVM IP |
| `DEPLOY_SSH_USER` | `root` or `ubuntu` | Your SSH user |
| `DEPLOY_SSH_PORT` | `22` | SSH port |
| `DEPLOY_SSH_KEY` | `-----BEGIN...` | From Step 4 (private key) |
| `DOCKER_HUB_MIRROR` | `mirror.ccs.tencentyun.com` | Optional, for faster builds |

## ✅ Verification

### Test 1: CCR Login
```bash
docker login ccr.ccs.tencentyun.com -u YOUR_SECRET_ID -p YOUR_SECRET_KEY
```

### Test 2: SSH Connection
```bash
ssh -i github-deploy user@your-cvm-ip
```

### Test 3: GitHub Actions
```bash
git commit -m "test" --allow-empty
git push origin main
# Watch GitHub Actions tab
```

### Test 4: Application Running
```bash
# On CVM
docker ps
curl http://localhost:3000
```

## 🛠️ Helper Scripts

```bash
# Setup CVM (run on CVM)
sudo bash scripts/setup-cvm.sh

# Configure Docker daemon (run on CVM)
sudo bash scripts/configure-docker-daemon.sh mirror.ccs.tencentyun.com

# Validate GitHub secrets (run locally)
bash scripts/validate-secrets.sh
```

## 📋 CVM Checklist

On your CVM, verify:

```bash
# Docker installed and running
docker --version
systemctl status docker

# Docker Compose installed
docker-compose --version

# Application directory exists
ls -la /app

# Environment file configured
cat /app/.env.production

# Docker daemon configured
cat /etc/docker/daemon.json

# Registry mirrors active
docker info | grep -A 5 "Registry Mirrors"

# Logged in to CCR
docker login ccr.ccs.tencentyun.com
```

## 🔥 Common Issues

### "unauthorized: authentication required"
→ Check CCR_USERNAME and CCR_PASSWORD in GitHub Secrets

### "Permission denied (publickey)"
→ Verify DEPLOY_SSH_KEY contains private key with BEGIN/END lines
→ Ensure public key is in `~/.ssh/authorized_keys` on CVM

### "pull access denied"
→ Login to CCR on CVM: `docker login ccr.ccs.tencentyun.com`

### "Connection refused"
→ Check CVM IP and firewall allows port 22

### "Container exits immediately"
→ Check `/app/.env.production` exists and is configured
→ View logs: `docker logs ai-chatbot`

## 📚 Full Documentation

- **Complete Guide**: [.github/CCR_SETUP_GUIDE.md](.github/CCR_SETUP_GUIDE.md)
- **Deployment Workflow**: [.github/DEPLOYMENT.md](.github/DEPLOYMENT.md)
- **Setup Instructions**: [.github/SETUP_INSTRUCTIONS.md](.github/SETUP_INSTRUCTIONS.md)
- **Scripts Documentation**: [scripts/README.md](../scripts/README.md)

## 🔐 Security Reminders

- ✅ Use deployment-specific SSH keys (not personal keys)
- ✅ Never commit `.env` or credentials to repository
- ✅ SSH key for CI/CD must have no passphrase
- ✅ Rotate credentials every 90 days
- ✅ Use private repositories in CCR
- ✅ Restrict CVM firewall to necessary ports only

## 🎯 After Setup

Once everything is configured:

1. Push code to `main` branch
2. Watch GitHub Actions run automatically
3. Verify deployment on CVM
4. Access your application at `http://your-cvm-ip:3000`
5. Set up domain and SSL/TLS certificate

## 💡 Tips

- Use `watch docker ps` on CVM to monitor container status
- Check `/app/deploy.log` for deployment history
- Use `docker-compose logs -f` to tail application logs
- Keep documentation updated with team-specific values
- Test the entire pipeline on a staging server first

---

**Need help?** See the full guides linked above or run `bash scripts/validate-secrets.sh` for detailed checklist.
