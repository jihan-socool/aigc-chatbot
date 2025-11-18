#!/usr/bin/env bash

set -euo pipefail

# Deployment script for Tencent CVM
# Called by GitHub Actions after successful Docker push to CCR
# Usage: ./scripts/deploy.sh

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Configuration
readonly APP_DIR="${APP_DIR:-/app}"
readonly LOG_FILE="${APP_DIR}/deploy.log"

log() {
  local level=$1
  shift
  local message="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

error() {
  echo -e "${RED}ERROR: $@${NC}" >&2
  log "ERROR" "$@"
  exit 1
}

success() {
  echo -e "${GREEN}✓ $@${NC}"
  log "INFO" "$@"
}

warning() {
  echo -e "${YELLOW}⚠ $@${NC}"
  log "WARN" "$@"
}

# Check if app directory exists
if [ ! -d "${APP_DIR}" ]; then
  error "Application directory ${APP_DIR} does not exist"
fi

cd "${APP_DIR}"

log "INFO" "Starting deployment..."

# Check Docker availability
if ! command -v docker &> /dev/null; then
  error "Docker is not installed"
fi

if ! command -v docker-compose &> /dev/null; then
  error "Docker Compose is not installed"
fi

log "INFO" "Docker and Docker Compose are available"

# Pull latest images
log "INFO" "Pulling latest images from CCR..."
if docker-compose pull; then
  success "Images pulled successfully"
else
  error "Failed to pull images"
fi

# Stop and remove old containers
log "INFO" "Stopping and removing old containers..."
if docker-compose down --remove-orphans; then
  success "Old containers removed"
else
  warning "Failed to stop/remove containers (may not exist yet)"
fi

# Start new containers
log "INFO" "Starting containers..."
if docker-compose up -d --remove-orphans; then
  success "Containers started successfully"
else
  error "Failed to start containers"
fi

# Wait for health check
log "INFO" "Waiting for application to become healthy..."
sleep 5

# Verify deployment
if docker-compose ps | grep -q "ai-chatbot"; then
  success "Deployment completed successfully"
  docker-compose ps
  log "INFO" "Deployment finished at $(date '+%Y-%m-%d %H:%M:%S')"
else
  error "Application container is not running"
fi
