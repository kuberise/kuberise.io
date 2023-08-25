#!/bin/bash

set -euo pipefail

GITHUB_TOKEN=${1-}               

if [ -z "${GITHUB_TOKEN}" ]
then 
  echo 1>&2 GITHUB_TOKEN is undefined
  exit 2
fi


if ! helm version &> /dev/null
then
    echo "Helm not found, installing helm..."
    
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
fi

# install cert-manager crds first
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.3/cert-manager.crds.yaml


# wait for github actions controller to be ready before lunching the runner deployment
helm upgrade --install --create-namespace -f apps/github-runner-controller/values.yaml \
    github-runner-controller apps/github-runner-controller --set github_token=${GITHUB_TOKEN} \
    --wait --namespace actions-runner-system --create-namespace

helm upgrade --install --create-namespace -f apps/github-runner/values.yaml \
    github-runner apps/github-runner --wait --namespace actions-runner-system 
