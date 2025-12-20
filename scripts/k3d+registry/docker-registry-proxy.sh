#!/bin/bash

set -euo pipefail

# Docker network name for k3d clusters
NETWORK_NAME="${NETWORK_NAME:-kuberise}"

# Create Docker network if it doesn't exist
if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Creating Docker network: $NETWORK_NAME"
  docker network create "$NETWORK_NAME"
fi

# Create directories for registry proxy
mkdir -p ~/docker_registry_proxy/mirror_cache
mkdir -p ~/docker_registry_proxy/certs

# Check if registry-proxy container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^registry-proxy$"; then
  if docker ps --format '{{.Names}}' | grep -q "^registry-proxy$"; then
    echo "Registry proxy container 'registry-proxy' is already running"
  else
    echo "Starting existing registry proxy container..."
    docker start registry-proxy
  fi
else
  echo "Creating registry proxy container..."
  docker run --name registry-proxy --restart unless-stopped \
    --network "$NETWORK_NAME" \
    -p 0.0.0.0:3128:3128 \
    -d \
    -v ~/docker_registry_proxy/mirror_cache:/docker_mirror_cache \
    -v ~/docker_registry_proxy/certs:/ca \
    -e ENABLE_MANIFEST_CACHE=true \
    -e REGISTRIES="registry.k8s.io gcr.io quay.io ghcr.io public.ecr.aws ecr-public.aws.com" \
    -e VERIFY_SSL=false \
    rpardini/docker-registry-proxy:0.6.5
fi
