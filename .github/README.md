# GitHub Configuration Documentation

This directory contains comprehensive documentation and configuration for the CI/CD pipeline and deployment to Tencent Cloud.

## 📚 Documentation Overview

### Quick Start
- **[CCR_QUICK_REFERENCE.md](CCR_QUICK_REFERENCE.md)** - 5-step quick reference card for CCR setup
- **[SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)** - Quick start guide for getting the pipeline running

### Complete Guides
- **[CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md)** - Complete step-by-step CCR configuration guide
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed CI/CD workflow documentation
- **[WORKFLOW_DIAGRAM.md](WORKFLOW_DIAGRAM.md)** - Visual diagrams of the deployment process

### Reference
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions
- **[README.md](README.md)** - This file (documentation index)

## 🚀 Quick Start

### For First-Time Setup

1. **Read the quick reference**:
   ```bash
   cat .github/CCR_QUICK_REFERENCE.md
   ```

2. **Run CVM setup script**:
   ```bash
   # On your Tencent CVM
   curl -fsSL https://raw.githubusercontent.com/your-repo/main/scripts/setup-cvm.sh | sudo bash
   ```

3. **Configure GitHub Secrets**:
   - Follow [CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md) Step 4

4. **Test the workflow**:
   ```bash
   git push origin main
   # Monitor in GitHub Actions tab
   ```

### For Troubleshooting

1. **Check common issues**:
   ```bash
   cat .github/TROUBLESHOOTING.md
   ```

2. **Validate configuration**:
   ```bash
   bash scripts/validate-secrets.sh
   ```

3. **Review workflow logs** in GitHub Actions tab

## 📖 Documentation Structure

```
.github/
├── README.md                     ← You are here
├── CCR_QUICK_REFERENCE.md        ← Start here for quick setup
├── CCR_SETUP_GUIDE.md            ← Complete configuration guide
├── SETUP_INSTRUCTIONS.md         ← Quick start instructions
├── DEPLOYMENT.md                 ← Workflow details
├── WORKFLOW_DIAGRAM.md           ← Visual process diagrams
├── TROUBLESHOOTING.md            ← Issue resolution
└── workflows/
    └── deploy.yml                ← GitHub Actions workflow

scripts/
├── README.md                     ← Scripts documentation
├── setup-cvm.sh                  ← One-click CVM setup
├── configure-docker-daemon.sh    ← Docker configuration
├── validate-secrets.sh           ← Secrets validation
└── deploy.sh                     ← Deployment script (runs on CVM)
```

## 🎯 Use Cases

### I need to... Where do I go?

| Task | Document |
|------|----------|
| Set up CCR for the first time | [CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md) |
| Quick reference for setup | [CCR_QUICK_REFERENCE.md](CCR_QUICK_REFERENCE.md) |
| Understand the workflow | [WORKFLOW_DIAGRAM.md](WORKFLOW_DIAGRAM.md) |
| Configure a new CVM | [scripts/README.md](../scripts/README.md) → setup-cvm.sh |
| Fix deployment issues | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Understand GitHub secrets | [CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md) Step 4 |
| Configure Docker daemon | [scripts/README.md](../scripts/README.md) → configure-docker-daemon.sh |
| Validate my configuration | Run `bash scripts/validate-secrets.sh` |
| Monitor deployments | [DEPLOYMENT.md](DEPLOYMENT.md) - Monitoring section |
| Roll back a deployment | [WORKFLOW_DIAGRAM.md](WORKFLOW_DIAGRAM.md) - Rollback section |

## 🔑 Required GitHub Secrets

Quick reference of all required secrets:

```bash
# CCR (Tencent Container Registry)
CCR_REGISTRY          # e.g., ccr.ccs.tencentyun.com
CCR_NAMESPACE         # Your CCR namespace
CCR_REPOSITORY        # Repository name
CCR_USERNAME          # Tencent SecretId (AKID...)
CCR_PASSWORD          # Tencent SecretKey

# CVM (Cloud Virtual Machine)
DEPLOY_SSH_HOST       # CVM public IP or domain
DEPLOY_SSH_USER       # SSH username (root/ubuntu)
DEPLOY_SSH_PORT       # SSH port (usually 22)
DEPLOY_SSH_KEY        # Private SSH key (full content)

# Optional
DOCKER_HUB_MIRROR     # e.g., mirror.ccs.tencentyun.com
```

See [CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md) for detailed explanations.

## 🛠️ Helper Scripts

All scripts are in the `scripts/` directory:

### Setup Scripts
- **`setup-cvm.sh`** - Complete CVM setup (Docker, Docker Compose, config)
- **`configure-docker-daemon.sh`** - Configure Docker registry mirrors

### Deployment Scripts
- **`deploy.sh`** - Deployment orchestration (called by GitHub Actions)

### Validation Scripts
- **`validate-secrets.sh`** - Validate GitHub secrets configuration

See [scripts/README.md](../scripts/README.md) for detailed documentation.

## 🔄 Workflow Overview

```
Push to main → GitHub Actions → Build Docker Image → 
Push to CCR → SSH to CVM → Pull & Deploy → Application Running
```

For detailed diagrams, see [WORKFLOW_DIAGRAM.md](WORKFLOW_DIAGRAM.md).

## 🏗️ Architecture

### Components

1. **GitHub Actions** - CI/CD automation
2. **Tencent CCR** - Docker image registry
3. **Tencent CVM** - Application hosting
4. **Docker Compose** - Container orchestration

### File Locations

```
Repository:
  .github/workflows/deploy.yml    → Workflow definition
  Dockerfile                      → Multi-stage build
  docker-compose.yml              → Service orchestration
  scripts/                        → Helper scripts

On CVM (/app):
  docker-compose.yml              → Service config
  .env                            → CCR image variables
  .env.production                 → App environment variables
  deploy.log                      → Deployment logs
```

## 📊 Monitoring

### During Deployment
- GitHub Actions → Actions tab → Watch workflow execution
- Check each step for success/failure

### After Deployment
```bash
# On CVM
docker ps                        # Container status
docker logs -f ai-chatbot        # Application logs
tail -f /app/deploy.log          # Deployment logs
docker stats ai-chatbot          # Resource usage
```

### Health Check
```bash
curl http://your-cvm-ip:3000
```

## 🆘 Getting Help

### Step 1: Check Documentation
1. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
2. [CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md) - Setup steps
3. [DEPLOYMENT.md](DEPLOYMENT.md) - Workflow details

### Step 2: Run Diagnostics
```bash
# Validate configuration
bash scripts/validate-secrets.sh

# Check CVM status
ssh user@cvm-ip "docker ps && docker logs ai-chatbot --tail 50"

# Check deployment logs
ssh user@cvm-ip "tail -50 /app/deploy.log"
```

### Step 3: Review Logs
- GitHub Actions → Actions tab → Select failed run
- CVM: `/app/deploy.log`
- Container: `docker logs ai-chatbot`

### Step 4: Test Components
```bash
# Test CCR login
docker login ccr.ccs.tencentyun.com -u USERNAME -p PASSWORD

# Test SSH
ssh -i key.pem user@cvm-ip

# Test application
curl http://cvm-ip:3000
```

## 🔐 Security Best Practices

- ✅ Use private CCR repositories
- ✅ Rotate credentials every 90 days
- ✅ Use deployment-specific SSH keys
- ✅ Never commit secrets to repository
- ✅ Restrict CVM firewall to necessary ports
- ✅ Keep Docker and dependencies updated
- ✅ Review access logs regularly
- ✅ Use strong passwords for databases
- ✅ Enable SSL/TLS for production
- ✅ Implement rate limiting

See [CCR_SETUP_GUIDE.md](CCR_SETUP_GUIDE.md) - Security section for details.

## 📝 Maintenance

### Regular Tasks

**Weekly**:
- Review deployment logs
- Check disk space on CVM
- Monitor container resource usage

**Monthly**:
- Update dependencies
- Review and rotate credentials
- Check for security updates
- Clean up unused Docker images

**Quarterly**:
- Audit access permissions
- Review and update documentation
- Test backup and recovery procedures
- Performance optimization review

### Cleanup Commands
```bash
# Remove unused Docker resources
docker system prune -a

# Clear old deployment logs
truncate -s 0 /app/deploy.log

# Remove old images
docker images | grep ai-chatbot | awk '{print $3}' | xargs docker rmi
```

## 🎓 Learning Path

### Beginner
1. Read [CCR_QUICK_REFERENCE.md](CCR_QUICK_REFERENCE.md)
2. Follow [SETUP_INSTRUCTIONS.md](SETUP_INSTRUCTIONS.md)
3. Run `setup-cvm.sh` on your CVM
4. Configure GitHub Secrets
5. Test with a simple push

### Intermediate
1. Understand [WORKFLOW_DIAGRAM.md](WORKFLOW_DIAGRAM.md)
2. Read [DEPLOYMENT.md](DEPLOYMENT.md) in detail
3. Customize workflow for your needs
4. Set up monitoring and alerts
5. Practice rollback procedures

### Advanced
1. Optimize Docker build times
2. Implement blue-green deployments
3. Add automated testing to workflow
4. Set up multi-stage environments
5. Implement custom health checks

## 🔗 External Resources

- [Tencent CCR Documentation](https://cloud.tencent.com/document/product/1141)
- [Tencent CVM Documentation](https://cloud.tencent.com/document/product/213)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

## 📄 License

This documentation is part of the project. See main repository LICENSE for details.

## 🤝 Contributing

When updating documentation:

1. Keep it clear and concise
2. Use practical examples
3. Test all commands before documenting
4. Update all related documents
5. Include troubleshooting sections
6. Add to this index if creating new documents

## 📋 Documentation Checklist

When setting up for the first time, complete these in order:

- [ ] Read [CCR_QUICK_REFERENCE.md](CCR_QUICK_REFERENCE.md)
- [ ] Create CCR namespace and repository
- [ ] Generate Tencent Cloud API credentials
- [ ] Run `setup-cvm.sh` on CVM
- [ ] Generate and configure SSH key
- [ ] Add all GitHub Secrets
- [ ] Configure `/app/.env.production` on CVM
- [ ] Run `validate-secrets.sh` locally
- [ ] Test CCR login
- [ ] Test SSH connection
- [ ] Push to main and monitor deployment
- [ ] Verify application is running
- [ ] Bookmark [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

---

**Questions?** Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) or review the relevant guide above.

**Ready to start?** Begin with [CCR_QUICK_REFERENCE.md](CCR_QUICK_REFERENCE.md)!
