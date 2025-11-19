# Troubleshooting Guide

Common issues and solutions for the Tencent CCR CI/CD pipeline.

## Table of Contents

- [GitHub Actions Issues](#github-actions-issues)
- [CCR Authentication Issues](#ccr-authentication-issues)
- [SSH Connection Issues](#ssh-connection-issues)
- [Docker Issues](#docker-issues)
- [Deployment Issues](#deployment-issues)
- [Application Issues](#application-issues)
- [Performance Issues](#performance-issues)

---

## GitHub Actions Issues

### Workflow Not Triggering

**Symptoms**: Push to main branch doesn't trigger the workflow

**Solutions**:
1. Check workflow is enabled:
   - Go to Actions tab → Select workflow
   - Check if it says "disabled"
2. Verify workflow file syntax:
   ```bash
   # Validate YAML syntax
   yamllint .github/workflows/deploy.yml
   ```
3. Check branch protection rules aren't blocking pushes
4. Verify you pushed to the correct branch (`main`)

### Workflow Permission Denied

**Symptoms**: `Error: Resource not accessible by integration`

**Solutions**:
1. Check workflow permissions:
   - Settings → Actions → General → Workflow permissions
   - Set to "Read and write permissions"
2. Verify the workflow has correct permissions:
   ```yaml
   permissions:
     contents: read
   ```

### Cache Issues

**Symptoms**: Build takes unusually long, cache not working

**Solutions**:
1. Clear GitHub Actions cache:
   - Actions tab → Caches → Delete old caches
2. Check cache size limits (10GB per repository)
3. Verify cache keys are consistent

---

## CCR Authentication Issues

### "unauthorized: authentication required"

**Symptoms**: Docker login fails or image push fails

**Solutions**:

1. **Verify credentials**:
   ```bash
   # Test login locally
   docker login ccr.ccs.tencentyun.com -u YOUR_SECRET_ID -p YOUR_SECRET_KEY
   ```

2. **Check GitHub Secrets**:
   - Settings → Secrets → Actions
   - Verify `CCR_USERNAME` is the SecretId (starts with `AKID`)
   - Verify `CCR_PASSWORD` is the SecretKey
   - Check for extra spaces or newlines in secrets

3. **Regenerate credentials**:
   - Tencent Cloud Console → Access Management → API Keys
   - Create new key and update GitHub Secrets

4. **Verify account permissions**:
   - Ensure account has CCR access
   - Check CAM policies include CCR permissions

### "repository does not exist"

**Symptoms**: `Error: manifest unknown: repository not found`

**Solutions**:

1. **Verify CCR repository exists**:
   - Login to Tencent Cloud Console → CCR
   - Check namespace and repository are created

2. **Check GitHub Secrets match**:
   ```bash
   # Expected format
   CCR_REGISTRY=ccr.ccs.tencentyun.com
   CCR_NAMESPACE=your-namespace  # Must match CCR
   CCR_REPOSITORY=your-repo      # Must match CCR
   ```

3. **Verify registry URL**:
   - For Guangzhou: `ccr.ccs.tencentyun.com`
   - Other regions may have different URLs

### "pull access denied"

**Symptoms**: Cannot pull images on CVM

**Solutions**:

1. **Login to CCR on CVM**:
   ```bash
   ssh user@cvm-ip
   docker login ccr.ccs.tencentyun.com
   ```

2. **Check repository visibility**:
   - CCR Console → Repository → Settings
   - Ensure you have access permissions

3. **Verify CVM can reach CCR**:
   ```bash
   ping ccr.ccs.tencentyun.com
   curl https://ccr.ccs.tencentyun.com/v2/
   ```

---

## SSH Connection Issues

### "Permission denied (publickey)"

**Symptoms**: GitHub Actions can't SSH to CVM

**Solutions**:

1. **Verify SSH key format**:
   ```bash
   # Private key must include BEGIN and END lines
   -----BEGIN OPENSSH PRIVATE KEY-----
   ...
   -----END OPENSSH PRIVATE KEY-----
   ```

2. **Check key has no passphrase**:
   ```bash
   # Test locally
   ssh -i your-key.pem user@cvm-ip
   # Should not ask for passphrase
   ```

3. **Verify public key on CVM**:
   ```bash
   ssh user@cvm-ip
   cat ~/.ssh/authorized_keys
   # Should contain your public key
   ```

4. **Check SSH key permissions**:
   ```bash
   # On CVM
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

5. **Regenerate SSH key**:
   ```bash
   ssh-keygen -t ed25519 -f github-deploy -N ""
   # Add public key to CVM
   ssh-copy-id -i github-deploy.pub user@cvm-ip
   # Add private key to GitHub Secret DEPLOY_SSH_KEY
   ```

### "Connection refused" or "Connection timeout"

**Symptoms**: Cannot connect to CVM

**Solutions**:

1. **Verify CVM is running**:
   - Check Tencent Cloud Console
   - Ensure instance state is "Running"

2. **Check SSH port**:
   ```bash
   # On CVM
   sudo netstat -tuln | grep :22
   ```

3. **Verify firewall rules**:
   - Tencent Cloud Console → Security Groups
   - Allow inbound TCP port 22 (SSH)
   - Allow from GitHub Actions IPs or 0.0.0.0/0

4. **Test SSH manually**:
   ```bash
   ssh -v user@cvm-ip -p 22
   # -v for verbose output to see where it fails
   ```

5. **Check DEPLOY_SSH_HOST**:
   - Must be public IP or domain
   - Not private IP

### "Host key verification failed"

**Symptoms**: SSH connection fails with host key error

**Solutions**:

1. **Add to known_hosts** (in GitHub Actions):
   ```yaml
   - name: Add known hosts
     run: |
       mkdir -p ~/.ssh
       ssh-keyscan -H ${{ secrets.DEPLOY_SSH_HOST }} >> ~/.ssh/known_hosts
   ```

2. **Or disable host key checking** (less secure):
   ```yaml
   with:
     host: ${{ secrets.DEPLOY_SSH_HOST }}
     strict_host_key_checking: false
   ```

---

## Docker Issues

### Docker Daemon Not Running

**Symptoms**: `Cannot connect to the Docker daemon`

**Solutions**:

1. **Start Docker service**:
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

2. **Check Docker status**:
   ```bash
   sudo systemctl status docker
   ```

3. **Reinstall Docker if needed**:
   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   ```

### "no space left on device"

**Symptoms**: Docker build or pull fails with disk space error

**Solutions**:

1. **Clean up Docker resources**:
   ```bash
   # Remove unused images
   docker image prune -a
   
   # Remove unused containers
   docker container prune
   
   # Remove unused volumes
   docker volume prune
   
   # Remove everything unused
   docker system prune -a --volumes
   ```

2. **Check disk space**:
   ```bash
   df -h
   du -sh /var/lib/docker/*
   ```

3. **Configure log rotation**:
   ```bash
   sudo bash scripts/configure-docker-daemon.sh
   ```

### "failed to compute cache key"

**Symptoms**: Docker build fails with cache error

**Solutions**:

1. **Clear buildx cache**:
   ```bash
   docker buildx prune -f
   ```

2. **Rebuild without cache**:
   ```bash
   docker-compose build --no-cache
   ```

---

## Deployment Issues

### Container Exits Immediately

**Symptoms**: `docker ps` shows no container running

**Solutions**:

1. **Check container logs**:
   ```bash
   docker logs ai-chatbot
   docker logs --tail 100 ai-chatbot
   ```

2. **Verify environment file**:
   ```bash
   # On CVM
   ls -la /app/.env.production
   cat /app/.env.production
   ```

3. **Check required variables**:
   ```bash
   # Must have at minimum
   DATABASE_URL=postgresql://...
   NODE_ENV=production
   ```

4. **Test container manually**:
   ```bash
   docker run -it --rm \
     --env-file /app/.env.production \
     ccr.ccs.tencentyun.com/namespace/repo:latest \
     sh
   ```

5. **Check port conflicts**:
   ```bash
   sudo netstat -tuln | grep :3000
   # Kill process if port in use
   sudo lsof -ti:3000 | xargs kill -9
   ```

### Health Check Failing

**Symptoms**: Container shows as "unhealthy"

**Solutions**:

1. **Check health endpoint**:
   ```bash
   docker exec ai-chatbot curl http://localhost:3000
   ```

2. **Review health check config**:
   ```yaml
   healthcheck:
     test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})"]
     interval: 30s
     timeout: 3s
     retries: 3
     start_period: 40s
   ```

3. **Increase start period if app takes long to start**:
   ```yaml
   start_period: 60s  # or longer
   ```

### Database Connection Failed

**Symptoms**: App logs show database connection errors

**Solutions**:

1. **Verify DATABASE_URL**:
   ```bash
   # Format: postgresql://user:pass@host:port/dbname
   echo $DATABASE_URL
   ```

2. **Test database connectivity**:
   ```bash
   # Install psql if needed
   sudo apt-get install postgresql-client
   
   # Test connection
   psql $DATABASE_URL
   ```

3. **Check database is accessible from CVM**:
   ```bash
   telnet db-host 5432
   # or
   nc -zv db-host 5432
   ```

4. **Verify firewall allows database connections**

---

## Application Issues

### "Module not found" Errors

**Symptoms**: App crashes with missing module errors

**Solutions**:

1. **Rebuild Docker image**:
   ```bash
   # Trigger new deployment
   git commit --allow-empty -m "rebuild"
   git push origin main
   ```

2. **Check dependencies in package.json**

3. **Verify build completed successfully in GitHub Actions**

### API Rate Limits

**Symptoms**: OpenAI API calls fail with rate limit errors

**Solutions**:

1. **Check API key and quota**:
   - OpenAI Dashboard → Usage
   - Verify not exceeding limits

2. **Implement rate limiting in app**

3. **Check OPENAI_API_KEY in .env.production**

### Session/Auth Issues

**Symptoms**: Users can't log in or sessions expire immediately

**Solutions**:

1. **Verify NEXTAUTH_SECRET**:
   ```bash
   # Must be set and at least 32 characters
   openssl rand -base64 32
   ```

2. **Check NEXTAUTH_URL**:
   ```bash
   # Should be your domain
   NEXTAUTH_URL=https://yourdomain.com
   ```

3. **Verify database schema**:
   ```bash
   pnpm db:migrate
   ```

---

## Performance Issues

### Slow Image Builds

**Solutions**:

1. **Enable Docker Hub mirror**:
   ```bash
   # On CVM
   sudo bash scripts/configure-docker-daemon.sh mirror.ccs.tencentyun.com
   ```

2. **Optimize Dockerfile**:
   - Use multi-stage builds
   - Order layers from least to most frequently changed
   - Use .dockerignore

3. **Use GitHub Actions cache**:
   ```yaml
   - uses: docker/build-push-action@v5
     with:
       cache-from: type=gha
       cache-to: type=gha,mode=max
   ```

### Slow Deployments

**Solutions**:

1. **Use Docker Hub mirror in workflow**:
   ```yaml
   - uses: docker/setup-buildx-action@v3
     with:
       driver-options: |
         image=${{ secrets.DOCKER_HUB_MIRROR }}
   ```

2. **Optimize dependencies**:
   - Remove unnecessary packages
   - Use production dependencies only

3. **Pre-pull common base images on CVM**:
   ```bash
   docker pull node:20-alpine
   ```

### High Memory Usage

**Solutions**:

1. **Limit container resources**:
   ```yaml
   services:
     app:
       deploy:
         resources:
           limits:
             memory: 1G
   ```

2. **Check application logs for memory leaks**

3. **Monitor with docker stats**:
   ```bash
   docker stats ai-chatbot
   ```

---

## Diagnostic Commands

### GitHub Actions

```bash
# View workflow runs
gh workflow view

# View latest run logs
gh run view --log

# Trigger manual workflow
gh workflow run deploy.yml
```

### On CVM

```bash
# Check running containers
docker ps -a

# Check container logs
docker logs -f ai-chatbot
docker logs --tail 100 ai-chatbot

# Check container resource usage
docker stats ai-chatbot

# Check container health
docker inspect ai-chatbot | grep Health -A 10

# Check deployment logs
tail -f /app/deploy.log

# Check disk space
df -h

# Check memory usage
free -h

# Check system logs
journalctl -xe
sudo tail -f /var/log/syslog

# Test application
curl http://localhost:3000
curl -I http://localhost:3000

# Check open ports
sudo netstat -tuln
sudo lsof -i :3000

# Check Docker network
docker network ls
docker network inspect app-network

# Check Docker daemon config
cat /etc/docker/daemon.json
docker info | grep -A 5 "Registry Mirrors"
```

### Database

```bash
# Connect to database
psql $DATABASE_URL

# Check tables
\dt

# Check user count
SELECT COUNT(*) FROM "User";

# Check recent chats
SELECT * FROM "Chat" ORDER BY "createdAt" DESC LIMIT 10;
```

---

## Getting Help

If you're still experiencing issues:

1. **Collect diagnostic information**:
   ```bash
   # Save all relevant logs
   docker logs ai-chatbot > app.log 2>&1
   docker-compose logs > compose.log 2>&1
   cat /app/deploy.log > deploy.log
   ```

2. **Check documentation**:
   - [CCR Setup Guide](CCR_SETUP_GUIDE.md)
   - [Deployment Guide](DEPLOYMENT.md)
   - [Setup Instructions](SETUP_INSTRUCTIONS.md)

3. **Validate configuration**:
   ```bash
   bash scripts/validate-secrets.sh
   ```

4. **Test components individually**:
   - CCR login
   - SSH connection
   - Docker on CVM
   - Application locally

5. **Review recent changes**:
   - What changed before the issue started?
   - Can you roll back to a working version?

---

## Prevention Tips

- ✅ **Test locally first** before pushing to main
- ✅ **Use staging environment** for major changes
- ✅ **Monitor workflows** after each deployment
- ✅ **Keep backups** of working configurations
- ✅ **Document custom configurations**
- ✅ **Rotate credentials regularly**
- ✅ **Update dependencies carefully**
- ✅ **Review logs regularly**
- ✅ **Set up alerts** for failed deployments
- ✅ **Maintain deployment runbooks**

---

**Last updated**: Check documentation for latest troubleshooting steps.
