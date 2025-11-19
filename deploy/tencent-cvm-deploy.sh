#!/bin/bash

# Tencent CVM Deployment Script
# This script logs into Tencent Container Registry (CCR), pulls the latest image,
# runs docker compose with production environment, prunes old images,
# and verifies container health.

set -euo pipefail

# Configuration
REGISTRY_URL="${REGISTRY_URL:-ccr.ccs.tencentyun.com}"
NAMESPACE="${NAMESPACE:-}"
IMAGE_NAME="${IMAGE_NAME:-aigc-chatbot}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
COMPOSE_DIR="${COMPOSE_DIR:-.}"
ENV_FILE="${ENV_FILE:-${COMPOSE_DIR}/.env.production}"
LOG_FILE="${LOG_FILE:-/var/log/aigc-chatbot-deploy.log}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-60}"
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}"

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
	command -v docker-compose &> /dev/null || error_exit "docker-compose is not installed"

	if [ ! -f "${ENV_FILE}" ]; then
		error_exit "Environment file not found: ${ENV_FILE}"
	fi

	success "All prerequisites are met"
}

# Login to Tencent Container Registry
login_to_registry() {
	log "INFO" "Logging into Tencent Container Registry..."

	if [ -z "${REGISTRY_USERNAME:-}" ] || [ -z "${REGISTRY_PASSWORD:-}" ]; then
		warn "REGISTRY_USERNAME or REGISTRY_PASSWORD not set, skipping login"
		return 0
	fi

	echo "${REGISTRY_PASSWORD}" | docker login -u "${REGISTRY_USERNAME}" --password-stdin "${REGISTRY_URL}" || error_exit "Failed to login to registry"

	success "Successfully logged into registry"
}

# Pull the latest image
pull_image() {
	log "INFO" "Pulling latest image from ${REGISTRY_URL}..."

	local full_image_name
	if [ -z "${NAMESPACE}" ]; then
		full_image_name="${REGISTRY_URL}/${IMAGE_NAME}:${IMAGE_TAG}"
	else
		full_image_name="${REGISTRY_URL}/${NAMESPACE}/${IMAGE_NAME}:${IMAGE_TAG}"
	fi

	docker pull "${full_image_name}" || error_exit "Failed to pull image: ${full_image_name}"

	success "Successfully pulled image: ${full_image_name}"
}

# Run docker-compose
run_compose() {
	log "INFO" "Starting docker-compose with production environment..."

	cd "${COMPOSE_DIR}" || error_exit "Cannot change to compose directory: ${COMPOSE_DIR}"

	docker-compose \
		--env-file="${ENV_FILE}" \
		--file=docker-compose.yml \
		up -d || error_exit "Failed to start docker-compose"

	success "docker-compose started successfully"
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
	login_to_registry
	pull_image
	run_compose
	verify_health
	prune_images

	log "INFO" "========== Deployment Completed Successfully =========="
}

# Execute main function
main "$@"
