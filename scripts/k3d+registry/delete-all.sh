#!/bin/bash

set -euo pipefail

NETWORK_NAME="${NETWORK_NAME:-kuberise}"

echo "Deleting k3d clusters..."

# Delete clusters (ignore errors if they don't exist)
k3d cluster delete dev 2>/dev/null || true
k3d cluster delete shared 2>/dev/null || true

# echo "Stopping and removing registry proxy container..."
# # Stop and remove registry proxy container (ignore errors if it doesn't exist)
# docker stop registry-proxy 2>/dev/null || true
# docker rm registry-proxy 2>/dev/null || true

# echo "Removing Docker network (if empty)..."
# # Remove network if it exists and is empty (ignore errors)
# docker network rm "$NETWORK_NAME" 2>/dev/null || true

echo "✓ Cleanup completed!"
echo ""
echo "Note: Image cache directories are preserved:"
echo "  - ~/docker_registry_proxy/"
echo "  - ~/tmp/k3d_docker_images/"
