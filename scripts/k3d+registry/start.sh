#!/bin/bash

set -euo pipefail

# export PROXY_HOST=registry-proxy
# export PROXY_PORT=3128
# export NOPROXY_LIST="localhost,127.0.0.1,0.0.0.0,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.local,.svc"

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
NETWORK_NAME="${NETWORK_NAME:-kuberise}"

# Expand home directory paths
HOME_DIR="${HOME}"
REGISTRY_PROXY_CERTS_DIR="${HOME_DIR}/docker_registry_proxy/certs"
K3D_IMAGES_DIR="${HOME_DIR}/tmp/k3d_docker_images"

# Create directories
mkdir -p "$REGISTRY_PROXY_CERTS_DIR"
mkdir -p "$K3D_IMAGES_DIR"
chmod 755 "$K3D_IMAGES_DIR"

# Run the docker registry proxy script first
echo "Starting the docker registry proxy..."
NETWORK_NAME="$NETWORK_NAME" "$SCRIPT_DIR"/docker-registry-proxy.sh

# Wait a moment for registry proxy to be ready
echo "Waiting for registry proxy to be ready..."
sleep 2

# Create temporary YAML files with expanded paths
SHARED_YAML_TMP=$(mktemp)
DEV_YAML_TMP=$(mktemp)

# Process shared.yaml: replace placeholders with actual paths
sed "s|__HOME_DIR__|${HOME_DIR}|g" "$SCRIPT_DIR/shared.yaml" > "$SHARED_YAML_TMP"

# Process dev.yaml: replace placeholders with actual paths
sed "s|__HOME_DIR__|${HOME_DIR}|g" "$SCRIPT_DIR/dev.yaml" > "$DEV_YAML_TMP"

# Cleanup function
cleanup() {
  rm -f "$SHARED_YAML_TMP" "$DEV_YAML_TMP"
}
trap cleanup EXIT

# Create shared cluster
if k3d cluster get shared >/dev/null 2>&1; then
  echo "k3d cluster 'shared' already exists"
else
  echo "Creating k3d cluster 'shared'..."
  k3d cluster create shared --config "$SHARED_YAML_TMP"
fi

# Create dev cluster
if k3d cluster get dev >/dev/null 2>&1; then
  echo "k3d cluster 'dev' already exists"
else
  echo "Creating k3d cluster 'dev'..."
  k3d cluster create dev --config "$DEV_YAML_TMP"
fi

echo ""
echo "✓ Both clusters created successfully!"
echo "  - shared cluster: k3d-shared"
echo "  - dev cluster: k3d-dev"
echo ""
echo "Next steps:"
echo "  1. Install Cilium CNI and ClusterMesh in both clusters"
echo "  2. Run install.sh for each cluster:"
echo "     ./scripts/install.sh k3d-shared shared <REPO_URL> <REVISION> <DOMAIN>"
echo "     ./scripts/install.sh k3d-dev dev <REPO_URL> <REVISION> <DOMAIN>"
