#!/usr/bin/env bash

# GitHub Actions Secrets Validation Script
# Validates that all required secrets are configured for the CI/CD pipeline
# Usage: bash validate-secrets.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Required secrets
declare -A REQUIRED_SECRETS=(
  ["CCR_REGISTRY"]="Tencent CCR registry host (e.g., ccr.ccs.tencentyun.com)"
  ["CCR_NAMESPACE"]="CCR namespace/project name"
  ["CCR_REPOSITORY"]="CCR repository name"
  ["CCR_USERNAME"]="CCR authentication username (Tencent SecretId)"
  ["CCR_PASSWORD"]="CCR authentication password (Tencent SecretKey)"
  ["DEPLOY_SSH_HOST"]="Target CVM IP address or domain"
  ["DEPLOY_SSH_USER"]="SSH username for CVM"
  ["DEPLOY_SSH_PORT"]="SSH port (default: 22)"
  ["DEPLOY_SSH_KEY"]="Private SSH key for authentication"
)

# Optional secrets
declare -A OPTIONAL_SECRETS=(
  ["DOCKER_HUB_MIRROR"]="Docker Hub mirror URL for faster builds in China"
)

# Functions
log_info() {
  echo -e "${BLUE}ℹ ${1}${NC}"
}

log_success() {
  echo -e "${GREEN}✓ ${1}${NC}"
}

log_warning() {
  echo -e "${YELLOW}⚠ ${1}${NC}"
}

log_error() {
  echo -e "${RED}✗ ${1}${NC}"
}

# Header
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}GitHub Actions Secrets Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

log_info "This script helps you verify that all required GitHub secrets are configured."
echo ""
log_warning "Note: This script cannot directly access GitHub secrets for security reasons."
log_info "You will need to manually verify each secret in your GitHub repository settings."
echo ""
echo "To access your secrets:"
echo "  1. Go to your GitHub repository"
echo "  2. Click Settings → Secrets and variables → Actions"
echo "  3. Verify each secret listed below exists"
echo ""

# Display required secrets
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}REQUIRED SECRETS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for secret in "${!REQUIRED_SECRETS[@]}"; do
  description="${REQUIRED_SECRETS[$secret]}"
  echo -e "${BLUE}Secret Name:${NC} ${secret}"
  echo -e "${YELLOW}Description:${NC} ${description}"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}OPTIONAL SECRETS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for secret in "${!OPTIONAL_SECRETS[@]}"; do
  description="${OPTIONAL_SECRETS[$secret]}"
  echo -e "${BLUE}Secret Name:${NC} ${secret}"
  echo -e "${YELLOW}Description:${NC} ${description}"
  echo ""
done

# Validation checklist
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}VALIDATION CHECKLIST${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<'EOF'
Please verify the following:

[ ] 1. CCR Configuration
    • CCR_REGISTRY is set to your registry URL (e.g., ccr.ccs.tencentyun.com)
    • CCR_NAMESPACE matches your Tencent Cloud namespace
    • CCR_REPOSITORY matches your repository name
    • CCR_USERNAME is your Tencent SecretId (starts with AKID...)
    • CCR_PASSWORD is your Tencent SecretKey

[ ] 2. SSH Configuration
    • DEPLOY_SSH_HOST is your CVM public IP or domain
    • DEPLOY_SSH_USER is the SSH username (usually 'root' or 'ubuntu')
    • DEPLOY_SSH_PORT is set (usually '22')
    • DEPLOY_SSH_KEY contains the PRIVATE key (including BEGIN/END lines)

[ ] 3. SSH Key Setup on CVM
    • The PUBLIC key is added to ~/.ssh/authorized_keys on the CVM
    • SSH key has no passphrase (required for automated deployments)
    • SSH connection can be established manually

[ ] 4. CVM Preparation
    • Docker is installed on the CVM
    • Docker Compose is installed on the CVM
    • /app directory exists on the CVM
    • /app/.env.production file is configured
    • /app/docker-compose.yml file exists

[ ] 5. CCR Repository
    • Namespace exists in Tencent Cloud Console
    • Repository exists in the namespace
    • Repository is set to Private (for production)
    • Credentials have push/pull access

[ ] 6. Optional Optimizations
    • DOCKER_HUB_MIRROR is set for faster builds (recommended for China)
    • Docker daemon.json is configured on CVM with mirror settings

EOF

# Example values
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}EXAMPLE SECRET VALUES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<'EOF'
CCR_REGISTRY=ccr.ccs.tencentyun.com
CCR_NAMESPACE=my-company
CCR_REPOSITORY=ai-chatbot
CCR_USERNAME=<your-tencent-secret-id>
CCR_PASSWORD=<your-tencent-secret-key>

DEPLOY_SSH_HOST=123.45.67.89
DEPLOY_SSH_USER=root
DEPLOY_SSH_PORT=22
DEPLOY_SSH_KEY=-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
...
(full private key content)
...
-----END OPENSSH PRIVATE KEY-----

DOCKER_HUB_MIRROR=mirror.ccs.tencentyun.com

EOF

# Testing section
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}MANUAL TESTING COMMANDS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<'EOF'
Test CCR Connection (from your local machine or CVM):
  docker login ccr.ccs.tencentyun.com -u YOUR_SECRET_ID -p YOUR_SECRET_KEY

Test SSH Connection (from your local machine):
  ssh -i /path/to/private-key.pem USER@HOST -p PORT

Test from GitHub Actions:
  1. Push a commit to the main branch
  2. Go to Actions tab in your repository
  3. Watch the workflow execution
  4. All steps should complete successfully

Verify on CVM after deployment:
  ssh user@host
  docker ps                          # Should show running container
  docker logs ai-chatbot             # Check application logs
  curl http://localhost:3000         # Test application response

EOF

# Common errors
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}COMMON ERRORS AND SOLUTIONS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<'EOF'
1. "unauthorized: authentication required"
   → Check CCR_USERNAME and CCR_PASSWORD are correct
   → Verify credentials have CCR access permissions
   → Regenerate API keys if needed

2. "Permission denied (publickey)"
   → Verify DEPLOY_SSH_KEY contains the PRIVATE key (not public)
   → Ensure public key is in ~/.ssh/authorized_keys on CVM
   → Check SSH key has no passphrase
   → Verify key format (should include BEGIN/END lines)

3. "pull access denied"
   → Login to CCR on the CVM manually first
   → Verify namespace and repository names are correct
   → Check repository exists and is accessible

4. "Connection refused" or "Connection timeout"
   → Verify DEPLOY_SSH_HOST is correct
   → Check CVM firewall allows SSH (port 22)
   → Ensure CVM is running and accessible

5. "Container exits immediately"
   → Check /app/.env.production exists and is configured
   → Verify database/redis URLs are correct and accessible
   → Review container logs: docker logs ai-chatbot

EOF

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}ADDITIONAL RESOURCES${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cat <<'EOF'
Documentation:
  • .github/CCR_SETUP_GUIDE.md - Complete CCR setup guide
  • .github/DEPLOYMENT.md - Deployment workflow documentation
  • .github/SETUP_INSTRUCTIONS.md - Quick start guide

Helper Scripts:
  • scripts/configure-docker-daemon.sh - Configure Docker on CVM
  • scripts/deploy.sh - Deployment script (runs on CVM)

EOF

echo ""
log_success "Validation checklist complete!"
echo ""
log_info "After verifying all secrets, test your workflow by:"
echo "  1. Making a small code change"
echo "  2. Pushing to the main branch"
echo "  3. Monitoring the GitHub Actions workflow"
echo ""
