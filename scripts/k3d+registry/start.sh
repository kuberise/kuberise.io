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
DEV_SHARED_ONPREM_YAML_TMP=$(mktemp)
DEV_APP_ONPREM_ONE_YAML_TMP=$(mktemp)

# Process dev-shared-onprem.yaml: replace placeholders with actual paths
sed "s|__HOME_DIR__|${HOME_DIR}|g" "$SCRIPT_DIR/dev-shared-onprem.yaml" > "$DEV_SHARED_ONPREM_YAML_TMP"

# Process dev-app-onprem-one.yaml: replace placeholders with actual paths
sed "s|__HOME_DIR__|${HOME_DIR}|g" "$SCRIPT_DIR/dev-app-onprem-one.yaml" > "$DEV_APP_ONPREM_ONE_YAML_TMP"

# Cleanup function
cleanup() {
  rm -f "$DEV_SHARED_ONPREM_YAML_TMP" "$DEV_APP_ONPREM_ONE_YAML_TMP"
}
trap cleanup EXIT

# Create dev-shared-onprem cluster
if k3d cluster get dev-shared-onprem >/dev/null 2>&1; then
  echo "k3d cluster 'dev-shared-onprem' already exists"
else
  echo "Creating k3d cluster 'dev-shared-onprem'..."
  k3d cluster create dev-shared-onprem --config "$DEV_SHARED_ONPREM_YAML_TMP"
fi

# Create dev-app-onprem-one cluster
if k3d cluster get dev-app-onprem-one >/dev/null 2>&1; then
  echo "k3d cluster 'dev-app-onprem-one' already exists"
else
  echo "Creating k3d cluster 'dev-app-onprem-one'..."
  k3d cluster create dev-app-onprem-one --config "$DEV_APP_ONPREM_ONE_YAML_TMP"
fi

echo ""
echo "✓ Both clusters created successfully!"
echo "  - dev-shared-onprem cluster: k3d-dev-shared-onprem"
echo "  - dev-app-onprem-one cluster: k3d-dev-app-onprem-one"
echo ""
echo "Next steps:"
echo "  1. Install Cilium CNI and ClusterMesh in both clusters"
echo "  2. Run install.sh for each cluster:"
echo "     ./scripts/install.sh k3d-dev-shared-onprem dev-shared-onprem <REPO_URL> <REVISION> <DOMAIN> <CILIUM_ID> <GITHUB_TOKEN>"
echo "     ./scripts/install.sh k3d-dev-app-onprem-one dev-app-onprem-one <REPO_URL> <REVISION> <DOMAIN> <CILIUM_ID> <GITHUB_TOKEN>"



# cluster ID 1 to 10 are reserved for shared clusters
# cluster ID 11 upwards are reserved for developer app clusters
REVISION=prometheusconfig
./scripts/install.sh k3d-dev-shared-onprem dev-shared-onprem https://github.com/kuberise/kuberise.io.git $REVISION dev.kuberise.dev 1 $GITHUB_TOKEN
./scripts/install.sh k3d-dev-app-onprem-one dev-app-onprem-one https://github.com/kuberise/kuberise.io.git $REVISION dev.kuberise.dev 11 $GITHUB_TOKEN
