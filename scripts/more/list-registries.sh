#!/bin/bash

# List unique container image registries used by all pods in a Kubernetes cluster.
# This script queries all pods across all namespaces, extracts the registry portion
# from container image names, and outputs a sorted unique list of registries.
#
# Usage: ./list-registries.sh <context>
# Example: ./list-registries.sh k3d-shared

set -euo pipefail

# Check if context is provided
if [ $# -eq 0 ]; then
  echo "Error: Kubernetes context is required"
  echo "Usage: $0 <context>"
  echo "Example: $0 k3d-shared"
  exit 1
fi

CONTEXT=$1

echo "Fetching unique image registries from cluster: $CONTEXT"
echo "----------------------------------------------------"

# 1. Get all container images from all namespaces
# 2. Use awk/sed to strip the image name/tag and keep only the registry
# 3. Sort and provide a unique list
kubectl get pods --context "$CONTEXT" --all-namespaces -o jsonpath='{.items[*].spec.containers[*].image}' | \
tr ' ' '\n' | \
awk -F'/' '
{
  if (NF > 1 && ($1 ~ /\./ || $1 ~ /:/)) {
    print $1
  } else {
    print "docker.io (official/library)"
  }
}' | sort -u

echo "----------------------------------------------------"
