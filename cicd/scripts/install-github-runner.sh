#!/bin/bash

if ! helm version &> /dev/null
then
    echo "Helm not found, installing helm..."
    
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
fi

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.3/cert-manager.crds.yaml


helm upgrade --install --create-namespace -f ./templates/github-runner-controller/values.yaml \
    github-runner-controller ./templates/github-runner-controller --set github_token=${GITHUB_TOKEN} \
    --wait --namespace actions-runner-system --create-namespace

helm upgrade --install --create-namespace -f ./templates/github-runner/values.yaml \
    github-runner ./templates/github-runner --wait --namespace actions-runner-system 
