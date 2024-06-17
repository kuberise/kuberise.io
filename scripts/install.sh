#!/bin/bash

set -euo pipefail

# Function Definitions

function check_required_tools() {
  local required_tools=("kubectl" "helm" "htpasswd")
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      echo "$tool could not be found, please install it."
      exit 1
    fi
  done
}

function create_namespace() {
  local context=$1
  local namespace=$2
  echo "Creating namespace: $namespace in context: $context"
  kubectl create namespace "$namespace" --context "$context" --dry-run=client -o yaml | kubectl apply --context "$context" -f -
}

function create_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local key_values=$4  # Pass --from-literal=key=value pairs space-separated
  echo "Creating secret: $secret_name in namespace: $namespace"
  kubectl create secret generic "$secret_name" --context "$context" -n "$namespace" $key_values --dry-run=client -o yaml | kubectl apply --context "$context" -n "$namespace" -f -
}

function label_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local label=$4
  echo "Labeling secret: $secret_name"
  kubectl label secret "$secret_name" "$label" --context "$context" -n "$namespace"
}

generate_ca_cert_and_key() {

  local context=$1
  local platform_name=$2
  local namespace=$3

  # Validate platform_name is provided
  if [ -z "$platform_name" ]; then
    echo "platform_name is required as an input parameter."
    return 1
  fi

  # Define the directory and file paths
  DIR=".env/$platform_name"
  CERT="$DIR/ca.crt"
  KEY="$DIR/ca.key"

  # Check if both the certificate and key files exist
  if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    echo "One or both of the CA certificate/key files do not exist. Generating..."

    # Create the directory structure if it doesn't exist
    mkdir -p "$DIR"

    # Generate the CA certificate and private key
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
      -keyout "$KEY" -out "$CERT" -subj "/CN=ca.kuberise.io CA/O=KUBERISE/C=NL"

    echo "CA certificate and key generated."
  else
    echo "CA certificate and key already exist."
  fi

  # Create a secret in the cert-manager namespace with the CA certificate
  kubectl create secret tls ca-key-pair-external \
    --cert="$CERT" \
    --key="$KEY" \
    --namespace="$namespace" \
    --dry-run=client -o yaml | kubectl apply --namespace="$namespace" --context="$context" -f -

  echo "Secret with CA certificate and key created in the $namespace namespace."
}

function install_argocd() {
  local context=$1
  local namespace=$2
  local values_file=$3
  local admin_password=$4
  echo "Installing ArgoCD using Helm..."
  BCRYPT_HASH=$(htpasswd -nbBC 10 "" "$admin_password" | tr -d ':\n' | sed 's/$2y/$2a/')
  helm upgrade --install --kube-context "$context" --wait --atomic -n "$namespace" --create-namespace  -f "$values_file" --version 6.9.2 --set configs.secret.argocdServerAdminPassword="$BCRYPT_HASH" --repo https://argoproj.github.io/argo-helm argocd argo-cd > /dev/null
}

function deploy_app_of_apps() {
  local context="$1"
  local namespace="$2"
  local platform_name="$3"
  local git_repo="$4"
  local git_revision="$5"

# create argocd project
cat <<EOF | kubectl apply --context $context -n $namespace -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $platform_name
  namespace: $namespace
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

# create app of apps
  kubectl apply --context "$context" -n "$namespace" -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps-$platform_name
  namespace: $namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  labels:
    team: platform
spec:
  project: $platform_name
  source:
    repoURL: $git_repo
    targetRevision: $git_revision
    path: ./app-of-apps
    helm:
      valueFiles:
        - values-$platform_name.yaml
      parameters:
        - name: global.spec.source.repoURL
          value: $git_repo
        - name: global.spec.source.targetRevision
          value: $git_revision
        - name: global.spec.values.repoURL
          value: $git_repo
        - name: global.spec.values.targetRevision
          value: $git_revision
        - name: global.platformName
          value: $platform_name
  destination:
    server: https://kubernetes.default.svc
    namespace: $namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
}

# Variables Initialization
# example: ./scripts/install.sh minikube local https://github.com/kuberise/kuberise.git main $GITHUB_TOKEN

CONTEXT=${1:-}                                          # example: platform-cluster
PLATFORM_NAME=${2:-local}                               # example: local, dta, azure etc. (default: local)
REPO_URL=${3:-}                                         # example: https://github.com/kuberise/kuberise.git
TARGET_REVISION=${4:-HEAD}                              # example: HEAD, main, master, v1.0.0, release
REPOSITORY_TOKEN=${5:-}

ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
PG_SUPERUSER_PASSWORD=${PG_SUPERUSER_PASSWORD:-superpassword}
# Generate random password for PG_APP_PASSWORD which is database password used by the platform services
PG_APP_USERNAME=application
PG_APP_PASSWORD=${PG_APP_PASSWORD:-apppassword}

if [ -z "$REPO_URL" ]; then
    echo "REPO_URL is undefined" 1>&2
    exit 2
fi

if [ -z "$TARGET_REVISION" ]; then
    echo "TARGET_REVISION is undefined" 1>&2
    exit 2
fi

if [ -z "$CONTEXT" ]; then
  echo "CONTEXT is undefined" 1>&2
  exit 2
fi

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "The ADMIN_PASSWORD environment variable is not set."
  exit 1
fi

# Namespace Definitions
NAMESPACE_ARGOCD="argocd"
NAMESPACE_CNPG="cloudnative-pg"
NAMESPACE_KEYCLOAK="keycloak"
NAMESPACE_BACKSTAGE="backstage"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_CERTMANAGER="cert-manager"

# Warning Message
echo "WARNING: This script will install the platform '$PLATFORM_NAME' in the Kubernetes context '$CONTEXT'. The following namespaces and applications will be installed:"
echo "- Namespace: $NAMESPACE_ARGOCD"
echo "- Namespace: $NAMESPACE_CNPG"
echo "- Namespace: $NAMESPACE_KEYCLOAK"
echo "- Namespace: $NAMESPACE_BACKSTAGE"
echo "- Namespace: $NAMESPACE_MONITORING"
echo "- Namespace: $NAMESPACE_CERTMANAGER"
echo "- Application: argocd-server"
echo "- Application: app-of-apps-$PLATFORM_NAME"
echo "Please confirm that you want to proceed by typing 'yes':"

read confirmation
if [ "$confirmation" != "yes" ]; then
  echo "Installation aborted."
  exit 0
fi

check_required_tools


# Create Namespaces
create_namespace "$CONTEXT" "$NAMESPACE_ARGOCD"
create_namespace "$CONTEXT" "$NAMESPACE_CNPG"
create_namespace "$CONTEXT" "$NAMESPACE_KEYCLOAK"
create_namespace "$CONTEXT" "$NAMESPACE_BACKSTAGE"
create_namespace "$CONTEXT" "$NAMESPACE_MONITORING"
create_namespace "$CONTEXT" "$NAMESPACE_CERTMANAGER"

# Create Secrets if TOKEN is provided
if [ -n "${REPOSITORY_TOKEN}" ]; then
  create_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-platform" "--from-literal=name=kuberise --from-literal=username=x --from-literal=password=$REPOSITORY_TOKEN --from-literal=url=$REPO_URL --from-literal=type=git"
  label_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-platform" "argocd.argoproj.io/secret-type=repository"

  # create_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-green-services" "--from-literal=name=green-services --from-literal=username=x --from-literal=password=$REPOSITORY_TOKEN --from-literal=url=https://github.com/kuberise/green-services.git --from-literal=type=git"
  # label_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-green-services" "argocd.argoproj.io/secret-type=repository"
  # TODO: Generation of teams and their repositories and projects will be done later by backstage
  # TODO: Or get a list of teams and their repositories and create repo secret and project for each of them in a loop
fi

generate_ca_cert_and_key "$CONTEXT" "$PLATFORM_NAME" "$NAMESPACE_CERTMANAGER"

# Secrets for PostgreSQL
create_secret "$CONTEXT" "$NAMESPACE_CNPG" "cnpg-database-app" "--from-literal=dbname=app --from-literal=host=cnpg-database-rw --from-literal=username=$PG_APP_USERNAME --from-literal=user=$PG_APP_USERNAME --from-literal=port=5432 --from-literal=password=$PG_APP_PASSWORD --type=kubernetes.io/basic-auth"
create_secret "$CONTEXT" "$NAMESPACE_CNPG" "cnpg-database-superuser" "--from-literal=dbname=* --from-literal=host=cnpg-database-rw --from-literal=username=postgres --from-literal=user=postgres --from-literal=port=5432 --from-literal=password=$PG_SUPERUSER_PASSWORD --type=kubernetes.io/basic-auth"

# Keycloak and Backstage and Grafana secrets
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "pg-secret" "--from-literal=KC_DB_USERNAME=$PG_APP_USERNAME --from-literal=KC_DB_PASSWORD=$PG_APP_PASSWORD"
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "admin-secret" "--from-literal=KEYCLOAK_ADMIN=admin --from-literal=KEYCLOAK_ADMIN_PASSWORD=$ADMIN_PASSWORD"
create_secret "$CONTEXT" "$NAMESPACE_BACKSTAGE" "pg-secret" "--from-literal=password=$PG_APP_PASSWORD"
create_secret "$CONTEXT" "$NAMESPACE_MONITORING" "grafana-admin" "--from-literal=admin-user=admin --from-literal=admin-password=$ADMIN_PASSWORD --from-literal=ldap-toml="

# Install ArgoCD with custom values and admin password
VALUES_FILE="values/$PLATFORM_NAME/argocd/values.yaml"
install_argocd "$CONTEXT" "$NAMESPACE_ARGOCD" "$VALUES_FILE" "$ADMIN_PASSWORD"

# Apply ArgoCD project and app of apps configuration
deploy_app_of_apps "$CONTEXT" "$NAMESPACE_ARGOCD" "$PLATFORM_NAME" "$REPO_URL" "$TARGET_REVISION"

echo "Installation completed successfully."
