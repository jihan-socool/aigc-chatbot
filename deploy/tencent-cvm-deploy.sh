#!/bin/bash

# Tencent CVM Deployment Script
# This script pulls the latest code, builds the Docker image locally,
# runs docker compose with production environment, prunes old images,
# and verifies container health.

set -euo pipefail

# Configuration
COMPOSE_DIR="${COMPOSE_DIR:-.}"
ENV_FILE="${ENV_FILE:-${COMPOSE_DIR}/.env.production}"
LOG_FILE="${LOG_FILE:-/var/log/aigc-chatbot-deploy.log}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-60}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}"
GIT_BRANCH="${GIT_BRANCH:-main}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Error handler
error_exit() {
    log "ERROR" "${RED}$*${NC}"
    exit 1
}

# Success handler
success() {
    log "INFO" "${GREEN}$*${NC}"
}

# Warning handler
warn() {
    log "WARN" "${YELLOW}$*${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "INFO" "Checking prerequisites..."

    command -v docker &> /dev/null || error_exit "Docker is not installed"
    command -v git &> /dev/null || error_exit "git is not installed"

    if [ ! -f "${ENV_FILE}" ]; then
        error_exit "Environment file not found: ${ENV_FILE}"
    fi

    success "All prerequisites are met"
}

# Pull latest code from git
pull_code() {
    log "INFO" "Pulling latest code from git..."

    cd "${COMPOSE_DIR}" || error_exit "Cannot change to compose directory: ${COMPOSE_DIR}"

    if [ ! -d ".git" ]; then
        error_exit "Not a git repository: ${COMPOSE_DIR}"
    fi

    git fetch origin || error_exit "Failed to fetch from remote"
    git reset --hard "origin/${GIT_BRANCH}" || error_exit "Failed to reset to origin/${GIT_BRANCH}"

    success "Successfully pulled latest code"
}

# Build Docker image locally
build_image() {
    log "INFO" "Building Docker image locally..."

    cd "${COMPOSE_DIR}" || error_exit "Cannot change to compose directory: ${COMPOSE_DIR}"

    docker compose build || error_exit "Failed to build Docker image"

    success "Successfully built Docker image"
}

# Run docker compose
run_compose() {
    log "INFO" "Starting docker compose with production environment..."

    cd "${COMPOSE_DIR}" || error_exit "Cannot change to compose directory: ${COMPOSE_DIR}"

    docker compose \
        --env-file="${ENV_FILE}" \
        --file=docker-compose.yml \
        up -d --remove-orphans || error_exit "Failed to start docker compose"

    success "docker compose started successfully"
}

# Verify container health
verify_health() {
    log "INFO" "Verifying container health (timeout: ${HEALTH_CHECK_TIMEOUT}s)..."

    local elapsed=0
    local service_name="${DOCKER_COMPOSE_SERVICE:-aigc-chatbot}"

    while [ $elapsed -lt "${HEALTH_CHECK_TIMEOUT}" ]; do
        if docker ps --filter "name=${service_name}" --filter "status=running" --quiet | grep -q .; then
            log "INFO" "Container is running"

            # Check if container is healthy
            local health_status
            health_status=$(docker inspect --format='{{.State.Health.Status}}' "${service_name}" 2>/dev/null || echo "unknown")

            if [ "${health_status}" = "healthy" ] || [ "${health_status}" = "unknown" ]; then
                success "Container health check passed (status: ${health_status})"
                return 0
            fi
        fi

        log "INFO" "Waiting for container to be ready (${elapsed}s/${HEALTH_CHECK_TIMEOUT}s)..."
        sleep "${HEALTH_CHECK_INTERVAL}"
        elapsed=$((elapsed + HEALTH_CHECK_INTERVAL))
    done

    error_exit "Container health check timed out"
}

# Prune old images
prune_images() {
    log "INFO" "Pruning unused Docker images..."

    docker image prune -f --filter "dangling=true" > /dev/null || error_exit "Failed to prune images"

    success "Old images pruned successfully"
}

# Main deployment flow
main() {
    log "INFO" "========== Tencent CVM Deployment Started =========="

    check_prerequisites
    pull_code
    build_image
    run_compose
    verify_health
    prune_images

    log "INFO" "========== Deployment Completed Successfully =========="
}

# Execute main function
main "$@"
