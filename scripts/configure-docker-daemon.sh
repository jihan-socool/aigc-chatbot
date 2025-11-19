#!/usr/bin/env bash

# Docker Daemon Configuration Script for Tencent CVM
# Configures Docker daemon with registry mirrors and logging settings
# Usage: sudo bash configure-docker-daemon.sh [mirror-url]

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly DAEMON_CONFIG_FILE="/etc/docker/daemon.json"
readonly DAEMON_CONFIG_BACKUP="/etc/docker/daemon.json.backup"
readonly DOCKER_DIR="/etc/docker"

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  error_exit "This script must be run as root. Please use: sudo $0"
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  error_exit "Docker is not installed. Please install Docker first."
fi

log_info "Docker Daemon Configuration Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get mirror URL from argument or use default
MIRROR_URL="${1:-mirror.ccs.tencentyun.com}"
log_info "Using Docker Hub mirror: ${MIRROR_URL}"

# Create docker directory if it doesn't exist
if [[ ! -d "${DOCKER_DIR}" ]]; then
  log_info "Creating Docker configuration directory..."
  mkdir -p "${DOCKER_DIR}"
  log_success "Directory created: ${DOCKER_DIR}"
fi

# Backup existing configuration
if [[ -f "${DAEMON_CONFIG_FILE}" ]]; then
  log_info "Backing up existing configuration..."
  cp "${DAEMON_CONFIG_FILE}" "${DAEMON_CONFIG_BACKUP}"
  log_success "Backup created: ${DAEMON_CONFIG_BACKUP}"
fi

# Create or update daemon.json
log_info "Creating Docker daemon configuration..."

# If existing config exists, try to merge; otherwise create new
if [[ -f "${DAEMON_CONFIG_FILE}" ]]; then
  # Check if jq is available for JSON manipulation
  if command -v jq &> /dev/null; then
    log_info "Merging with existing configuration..."
    
    # Read existing config and update with new values
    TEMP_CONFIG=$(mktemp)
    jq --arg mirror "https://${MIRROR_URL}" \
      '.["registry-mirrors"] = (if .["registry-mirrors"] then .["registry-mirrors"] + [$mirror] else [$mirror] end | unique) |
       .["log-driver"] = "json-file" |
       .["log-opts"] = {"max-size": "10m", "max-file": "3"}' \
      "${DAEMON_CONFIG_FILE}" > "${TEMP_CONFIG}"
    
    mv "${TEMP_CONFIG}" "${DAEMON_CONFIG_FILE}"
  else
    log_warning "jq not found, replacing configuration file..."
    create_new_config
  fi
else
  create_new_config
fi

# Validate JSON syntax
log_info "Validating configuration..."
if command -v python3 &> /dev/null; then
  if python3 -m json.tool "${DAEMON_CONFIG_FILE}" > /dev/null 2>&1; then
    log_success "Configuration file is valid JSON"
  else
    log_error "Invalid JSON in configuration file!"
    if [[ -f "${DAEMON_CONFIG_BACKUP}" ]]; then
      log_warning "Restoring backup..."
      cp "${DAEMON_CONFIG_BACKUP}" "${DAEMON_CONFIG_FILE}"
    fi
    error_exit "Failed to create valid configuration. Backup restored if available."
  fi
elif command -v jq &> /dev/null; then
  if jq empty "${DAEMON_CONFIG_FILE}" > /dev/null 2>&1; then
    log_success "Configuration file is valid JSON"
  else
    error_exit "Invalid JSON in configuration file!"
  fi
else
  log_warning "Cannot validate JSON (python3 or jq not found). Proceeding anyway..."
fi

# Display the configuration
log_info "Current Docker daemon configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "${DAEMON_CONFIG_FILE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Reload Docker daemon
log_info "Reloading Docker daemon..."
if systemctl daemon-reload; then
  log_success "Daemon reloaded"
else
  error_exit "Failed to reload daemon"
fi

log_info "Restarting Docker service..."
if systemctl restart docker; then
  log_success "Docker service restarted"
else
  error_exit "Failed to restart Docker service"
fi

# Wait for Docker to be ready
log_info "Waiting for Docker to be ready..."
sleep 3

# Verify Docker is running
if systemctl is-active --quiet docker; then
  log_success "Docker is running"
else
  error_exit "Docker failed to start"
fi

# Display registry mirrors
log_info "Verifying registry mirrors configuration..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker info | grep -A 10 "Registry Mirrors:" || log_warning "Registry mirrors not shown in docker info"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test mirror connectivity (optional)
log_info "Testing mirror connectivity..."
if curl -sSf "https://${MIRROR_URL}" > /dev/null 2>&1; then
  log_success "Mirror is accessible"
else
  log_warning "Mirror may not be accessible (this might be expected)"
fi

# Summary
echo ""
log_success "Docker daemon configuration completed successfully!"
echo ""
echo "Configuration details:"
echo "  • Config file: ${DAEMON_CONFIG_FILE}"
echo "  • Backup file: ${DAEMON_CONFIG_BACKUP}"
echo "  • Registry mirror: https://${MIRROR_URL}"
echo "  • Log driver: json-file (max 10MB × 3 files)"
echo ""
echo "Next steps:"
echo "  1. Test Docker by pulling an image: docker pull hello-world"
echo "  2. Login to CCR: docker login ccr.ccs.tencentyun.com"
echo "  3. Review docker info output for registry mirrors"
echo ""

# Function to create new config
create_new_config() {
  cat > "${DAEMON_CONFIG_FILE}" <<EOF
{
  "registry-mirrors": [
    "https://${MIRROR_URL}"
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
}
