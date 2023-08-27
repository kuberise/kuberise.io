#!/bin/bash

set -euo pipefail

CONTEXT=${1-}               # example: minikube-dta
ENVIRONMENT=${2-dta}        # example: dta or prd (defaults to dta)
REPOSITORY_TOKEN=${3-}      # example: 1234567890qpoieraksjdhzxcbv 

# context MUST be set to connect to the k8s cluster
if [ -z "${CONTEXT}" ]
then 
  echo 1>&2 CONTEXT is undefined
  exit 2
fi


# create namespace
NAMESPACE=argocd
REPOSITORY=https://github.com/kuberise/kuberise.git

kubectl create namespace $NAMESPACE --context $CONTEXT --dry-run=client -o yaml | kubectl apply --context $CONTEXT -f -

# create secret for repository if token is set for it 
if [ -n "${REPOSITORY_TOKEN}" ]
then
kubectl create secret generic git-credentials --context $CONTEXT -n $NAMESPACE \
  --from-literal=name=kuberise \
  --from-literal=username=x \
  --from-literal=password=$REPOSITORY_TOKEN \
  --from-literal=url=$REPOSITORY \
  --from-literal=type=git \
  --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n $NAMESPACE -f -
kubectl label secret git-credentials argocd.argoproj.io/secret-type=repository --context $CONTEXT -n $NAMESPACE
fi 

# install argocd using helm
PROJECT_NAME=platform-$ENVIRONMENT
VALUES_FILE=values/argocd/values-$ENVIRONMENT.yaml
helm repo add argocd https://argoproj.github.io/argo-helm
helm repo update
helm upgrade --install --kube-context $CONTEXT -n $NAMESPACE -f $VALUES_FILE argocd argocd/argo-cd --version 5.42.2 --wait


# add project to the argocd server using yaml file
cat <<EOF | kubectl apply --context $CONTEXT -n $NAMESPACE -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $PROJECT_NAME
  namespace: $NAMESPACE
  # Finalizer that ensures that project is not deleted until it is not referenced by any application
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - name: '*'
    namespace: '*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF

# add app of the apps to the argocd server using yaml file
kubectl apply --context $CONTEXT -n $NAMESPACE -f cicd/argocd/app-of-apps-$ENVIRONMENT.yaml
