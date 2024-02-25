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

kubectl create namespace $NAMESPACE --context $CONTEXT --dry-run=client -o yaml | kubectl apply --context $CONTEXT -f -

# create secret for repository if token is set for it
if [ -n "${REPOSITORY_TOKEN}" ]
then
kubectl create secret generic argocd-repo-platform --context $CONTEXT -n $NAMESPACE \
  --from-literal=name=kuberise \
  --from-literal=username=x \
  --from-literal=password=$REPOSITORY_TOKEN \
  --from-literal=url=https://github.com/kuberise/kuberise.git \
  --from-literal=type=git \
  --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n $NAMESPACE -f -
kubectl label secret argocd-repo-platform argocd.argoproj.io/secret-type=repository --context $CONTEXT -n $NAMESPACE

kubectl create secret generic argocd-repo-green-services --context $CONTEXT -n $NAMESPACE \
  --from-literal=name=green-services \
  --from-literal=username=x \
  --from-literal=password=$REPOSITORY_TOKEN \
  --from-literal=url=https://github.com/kuberise/green-services.git \
  --from-literal=type=git \
  --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n $NAMESPACE -f -
kubectl label secret argocd-repo-green-services argocd.argoproj.io/secret-type=repository --context $CONTEXT -n $NAMESPACE
fi

# generate secrets(this is temporary until we have vault for secret management )
# Check if the ADMIN_PASSWORD environment variable is set
if [ -z "$ADMIN_PASSWORD" ]; then
  echo "The ADMIN_PASSWORD environment variable is not set."
  exit 1
fi
# Create secret for postgresql from environment variable
kubectl create namespace cloudnative-pg --context $CONTEXT --dry-run=client -o yaml | kubectl apply --context $CONTEXT -f -
# a secret for the postgresql database for apps
kubectl create secret generic cnpg-database-app \
  --from-literal=dbname=app \
  --from-literal=host=cnpg-database-rw \
  --from-literal=username=app \
  --from-literal=user=app \
  --from-literal=port=5432 \
  --from-literal=password="$ADMIN_PASSWORD" \
  --type=kubernetes.io/basic-auth \
  --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n cloudnative-pg -f -

# a secret for the postgresql database for superuser
kubectl create secret generic cnpg-database-superuser \
  --from-literal=dbname='*' \
  --from-literal=host=cnpg-database-rw \
  --from-literal=username=postgres \
  --from-literal=user=postgres \
  --from-literal=port=5432 \
  --from-literal=password="$PG_SUPERUSER_PASSWORD" \
  --type=kubernetes.io/basic-auth \
  --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n cloudnative-pg -f -

# Create secret for keycloak from environment variable
kubectl create namespace keycloak --context $CONTEXT --dry-run=client -o yaml | kubectl apply --context $CONTEXT -f -
kubectl create secret generic pg-secret --type=kubernetes.io/basic-auth --from-literal=password="$ADMIN_PASSWORD" --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n keycloak -f -

# Create secret for backstage from environment variable
kubectl create namespace backstage --context $CONTEXT --dry-run=client -o yaml | kubectl apply --context $CONTEXT -f -
kubectl create secret generic pg-secret --type=kubernetes.io/basic-auth --from-literal=password="$ADMIN_PASSWORD" --dry-run=client -o yaml | kubectl apply --context $CONTEXT -n backstage -f -

# Create secret for argocd admin password from environment variable
# Generate bcrypt hash of the admin password
BCRYPT_HASH=$(htpasswd -nbBC 10 "" $ADMIN_PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/')

# install argocd using helm
PROJECT_NAME=platform-$ENVIRONMENT
VALUES_FILE=values/argocd/values-$ENVIRONMENT.yaml
# helm repo add argocd https://argoproj.github.io/argo-helm
# helm repo update
echo Installing argocd using helm...
helm upgrade --install --kube-context $CONTEXT -n $NAMESPACE -f $VALUES_FILE argocd argocd/argo-cd --version 6.1.0 --wait --set configs.secret.argocdServerAdminPassword=$BCRYPT_HASH > /dev/null


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
