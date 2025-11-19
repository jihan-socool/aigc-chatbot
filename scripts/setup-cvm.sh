#!/usr/bin/env bash

# CVM Setup Script for Tencent Cloud
# Prepares a fresh CVM instance for Docker deployment
# Usage: sudo bash setup-cvm.sh

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly APP_DIR="/app"
readonly DOCKER_MIRROR="${DOCKER_MIRROR:-mirror.ccs.tencentyun.com}"

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
  echo -e "${RED}✗ ${1}${NC}" >&2
}

error_exit() {
  log_error "$1"
  exit 1
}

prompt_user() {
  local prompt_msg="$1"
  local default_value="${2:-}"
  local user_input
  
  if [[ -n "${default_value}" ]]; then
    read -p "$(echo -e "${BLUE}${prompt_msg} [${default_value}]:${NC} ")" user_input
    echo "${user_input:-${default_value}}"
  else
    read -p "$(echo -e "${BLUE}${prompt_msg}:${NC} ")" user_input
    echo "${user_input}"
  fi
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  error_exit "This script must be run as root. Please use: sudo $0"
fi

# Header
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Tencent CVM Setup Script${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_info "This script will set up your CVM for Docker deployment"
echo ""

# Step 1: Update system
log_info "Step 1/7: Updating system packages..."
if apt-get update -qq && apt-get upgrade -y -qq; then
  log_success "System updated"
else
  log_warning "System update had some issues, continuing anyway..."
fi

# Step 2: Install dependencies
log_info "Step 2/7: Installing required dependencies..."
if apt-get install -y -qq curl git ca-certificates gnupg lsb-release jq; then
  log_success "Dependencies installed"
else
  error_exit "Failed to install dependencies"
fi

# Step 3: Install Docker
log_info "Step 3/7: Checking Docker installation..."
if command -v docker &> /dev/null; then
  DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
  log_success "Docker is already installed (version ${DOCKER_VERSION})"
else
  log_info "Installing Docker..."
  
  # Download and run Docker installation script
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  if sh /tmp/get-docker.sh; then
    log_success "Docker installed successfully"
    rm /tmp/get-docker.sh
  else
    error_exit "Failed to install Docker"
  fi
fi

# Enable and start Docker service
systemctl enable docker
systemctl start docker

# Add current user to docker group (if not root)
if [[ -n "${SUDO_USER:-}" ]]; then
  usermod -aG docker "${SUDO_USER}"
  log_success "Added ${SUDO_USER} to docker group"
  log_warning "Note: You'll need to log out and back in for group changes to take effect"
fi

# Step 4: Install Docker Compose
log_info "Step 4/7: Checking Docker Compose installation..."
if command -v docker-compose &> /dev/null; then
  COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f4 | tr -d ',')
  log_success "Docker Compose is already installed (version ${COMPOSE_VERSION})"
else
  log_info "Installing Docker Compose..."
  
  # Get latest version
  COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
  COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
  
  if curl -L "${COMPOSE_URL}" -o /usr/local/bin/docker-compose; then
    chmod +x /usr/local/bin/docker-compose
    log_success "Docker Compose installed successfully (${COMPOSE_VERSION})"
  else
    error_exit "Failed to install Docker Compose"
  fi
fi

# Step 5: Configure Docker daemon
log_info "Step 5/7: Configuring Docker daemon..."

DAEMON_CONFIG="/etc/docker/daemon.json"
mkdir -p /etc/docker

# Create daemon.json with registry mirrors
cat > "${DAEMON_CONFIG}" <<EOF
{
  "registry-mirrors": [
    "https://${DOCKER_MIRROR}"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false
}
EOF

# Reload and restart Docker
systemctl daemon-reload
systemctl restart docker

log_success "Docker daemon configured with registry mirror"

# Step 6: Create application directory
log_info "Step 6/7: Setting up application directory..."

if [[ ! -d "${APP_DIR}" ]]; then
  mkdir -p "${APP_DIR}"
  log_success "Created ${APP_DIR}"
else
  log_success "${APP_DIR} already exists"
fi

cd "${APP_DIR}"

# Step 7: Interactive configuration
log_info "Step 7/7: Creating configuration files..."
echo ""

# Prompt for CCR credentials
log_info "CCR Configuration (press Enter to skip and configure manually later)"
CCR_REGISTRY=$(prompt_user "Enter CCR registry" "ccr.ccs.tencentyun.com")
CCR_NAMESPACE=$(prompt_user "Enter CCR namespace" "")
CCR_REPOSITORY=$(prompt_user "Enter CCR repository" "")

# Create .env file for docker-compose
if [[ -n "${CCR_NAMESPACE}" ]] && [[ -n "${CCR_REPOSITORY}" ]]; then
  cat > "${APP_DIR}/.env" <<EOF
CCR_REGISTRY=${CCR_REGISTRY}
CCR_NAMESPACE=${CCR_NAMESPACE}
CCR_REPOSITORY=${CCR_REPOSITORY}
EOF
  log_success "Created ${APP_DIR}/.env"
else
  log_warning "Skipped .env creation - configure manually later"
fi

# Create docker-compose.yml
log_info "Creating docker-compose.yml..."
cat > "${APP_DIR}/docker-compose.yml" <<'EOF'
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
log_success "Created ${APP_DIR}/docker-compose.yml"

# Create template .env.production
log_info "Creating .env.production template..."
cat > "${APP_DIR}/.env.production.template" <<'EOF'
# Production Environment Variables
# Copy this to .env.production and fill in your values

# Node Environment
NODE_ENV=production
PORT=3000

# Database Configuration
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Redis Configuration (if using)
REDIS_URL=redis://host:6379

# Authentication (if using NextAuth)
NEXTAUTH_URL=https://yourdomain.com
NEXTAUTH_SECRET=your-random-secret-key-min-32-chars

# AI Provider Configuration
OPENAI_API_KEY=sk-your-openai-key

# Add other environment variables as needed
EOF

if [[ ! -f "${APP_DIR}/.env.production" ]]; then
  cp "${APP_DIR}/.env.production.template" "${APP_DIR}/.env.production"
  log_success "Created ${APP_DIR}/.env.production (please edit with your values)"
else
  log_warning "${APP_DIR}/.env.production already exists, not overwriting"
fi

# Set proper permissions
chmod 600 "${APP_DIR}/.env.production"
chmod 644 "${APP_DIR}/docker-compose.yml"

# Test Docker installation
echo ""
log_info "Testing Docker installation..."
if docker run --rm hello-world > /dev/null 2>&1; then
  log_success "Docker is working correctly"
else
  log_warning "Docker test failed, but installation completed"
fi

# Display summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installed:"
echo "  • Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
echo "  • Docker Compose $(docker-compose --version | cut -d' ' -f4 | tr -d ',')"
echo ""
echo "Configuration:"
echo "  • Application directory: ${APP_DIR}"
echo "  • Docker daemon config: /etc/docker/daemon.json"
echo "  • Registry mirror: ${DOCKER_MIRROR}"
echo ""
echo "Created files:"
echo "  • ${APP_DIR}/.env"
echo "  • ${APP_DIR}/docker-compose.yml"
echo "  • ${APP_DIR}/.env.production (template)"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Edit ${APP_DIR}/.env.production with your configuration"
echo "  2. Login to CCR: docker login ${CCR_REGISTRY}"
echo "  3. Test pulling your image:"
echo "     cd ${APP_DIR} && docker-compose pull"
echo "  4. Configure GitHub Actions secrets (see .github/CCR_SETUP_GUIDE.md)"
echo "  5. Add deployment SSH key to ~/.ssh/authorized_keys"
echo ""
echo "If you added a user to the docker group, log out and back in for changes to take effect."
echo ""

# Offer to login to CCR
echo ""
read -p "$(echo -e "${BLUE}Would you like to login to CCR now? (y/N):${NC} ")" -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  log_info "Logging in to CCR..."
  if [[ -n "${CCR_REGISTRY}" ]]; then
    docker login "${CCR_REGISTRY}"
  else
    docker login ccr.ccs.tencentyun.com
  fi
fi

log_success "CVM setup completed successfully!"
