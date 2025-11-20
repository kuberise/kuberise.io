#!/bin/bash

# Run the docker registry proxy script first
echo "Starting the docker registry proxy... "
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
"$SCRIPT_DIR"/docker-registry-proxy.sh

export PROXY_HOST=registry-proxy
export PROXY_PORT=3128
export NOPROXY_LIST="localhost,127.0.0.1,0.0.0.0,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.local,.svc"

# to keep the pulled images when you delete and recreate the cluster
mkdir -p ~/tmp/k3d_docker_images
chmod 755 ~/tmp/k3d_docker_images

if k3d cluster get shared >/dev/null 2>&1; then
  echo "k3d cluster 'shared' already exists"
else
  k3d cluster create shared --config "$SCRIPT_DIR"/shared.yaml
fi

if k3d cluster get dev >/dev/null 2>&1; then
  echo "k3d cluster 'dev' already exists"
else
  k3d cluster create dev --config "$SCRIPT_DIR"/dev.yaml
fi
