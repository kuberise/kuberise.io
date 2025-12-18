#!/bin/bash

set -euo pipefail

# Function Definitions

function check_required_tools() {
  local required_tools=("kubectl" "helm" "htpasswd" "openssl" "cilium" "yq")
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
  # echo "Creating namespace: $namespace in context: $context"
  kubectl create namespace "$namespace" --context "$context" --dry-run=client -o yaml | kubectl apply --context "$context" -f -
}

function create_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local key_values=$4  # Pass --from-literal=key=value pairs space-separated
  # echo "Creating secret: $secret_name in namespace: $namespace"
  kubectl create secret generic "$secret_name" --context "$context" -n "$namespace" $key_values --dry-run=client -o yaml | kubectl apply --context "$context" -n "$namespace" -f -
}

function label_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local label=$4
  # echo "Labeling secret: $secret_name"
  kubectl label secret "$secret_name" "$label" --context "$context" -n "$namespace"
}

function generate_ca_cert_and_key() {
  local context=$1

  # Define the directory and file paths
  DIR=".env"
  CERT="$DIR/ca.crt"
  KEY="$DIR/ca.key"
  CA_BUNDLE="$DIR/ca-bundle.crt"

  # Check if both the certificate and key files exist
  if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    echo "One or both of the CA certificate/key files do not exist. Generating..."

    # Create the directory structure if it doesn't exist
    mkdir -p "$DIR"

    # Generate the CA certificate and private key
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
      -keyout "$KEY" -out "$CERT" -subj "/CN=ca.kuberise.local CA/O=KUBERISE/C=NL"

    echo "CA certificate and key generated."
  else
    echo "CA certificate and key already exist."
  fi

  # Download Let's Encrypt root certificate and create CA bundle
  echo "Creating CA bundle with self-signed and Let's Encrypt certificates..."

  # Get the directory of the script
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # Copy the local letsencrypt.crt file instead of downloading it
  cp "$SCRIPT_DIR/letsencrypt.crt" "$DIR/letsencrypt.crt"

  cat "$CERT" "$DIR/letsencrypt.crt" > "$CA_BUNDLE"
  rm "$DIR/letsencrypt.crt"  # Clean up temporary file

  # Create a secret in the cert-manager namespace with the CA certificate
  kubectl create secret tls ca-key-pair-external \
    --cert="$CERT" \
    --key="$KEY" \
    --namespace="cert-manager" \
    --dry-run=client -o yaml | kubectl apply --namespace="cert-manager" --context="$context" -f -

  # List of namespaces to create self-signed CA certificate ConfigMap
  namespaces=("pgadmin" "monitoring" "argocd" "keycloak" "backstage" "postgres" "cert-manager" "external-dns")

  # Iterate over each namespace and create the configmap with the CA bundle
  for namespace in "${namespaces[@]}"; do
    # Create the configmap in the current namespace using the CA bundle
    kubectl create configmap ca-bundle \
      --from-file=ca.crt="$CA_BUNDLE" \
      --namespace="$namespace" \
      --dry-run=client -o yaml | kubectl apply --namespace="$namespace" --context="$context" -f -
  done

  echo "CA bundle created and ConfigMaps updated in all namespaces."
}

function install_argocd() {
  local context=$1
  local namespace=$2
  local cluster_name=$3
  local admin_password=$4
  local domain=$5
  echo "Installing ArgoCD using Helm..."
  BCRYPT_HASH=$(htpasswd -nbBC 10 "" "$admin_password" | tr -d ':\n' | sed 's/$2y/$2a/')
  helm upgrade \
    --install \
    --kube-context "$context" \
    -n "$namespace" \
    --create-namespace  \
    --wait \
    -f values/defaults/platform/argocd/values.yaml \
    -f values/$cluster_name/platform/argocd/values.yaml \
    --set server.ingress.hostname=argocd."$domain" \
    --set global.domain=argocd."$domain" \
    --set configs.secret.argocdServerAdminPassword="$BCRYPT_HASH" \
    --repo https://argoproj.github.io/argo-helm \
    --version 9.1.8 \
    argocd argo-cd > /dev/null
}

function deploy_app_of_apps() {
  local context="$1"
  local namespace="$2"
  local cluster_name="$3"
  local git_repo="$4"
  local git_revision="$5"
  local domain="$6"

# create argocd project
cat <<EOF | kubectl apply --context $context -n $namespace -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $cluster_name
  namespace: $namespace
  # Finalizer that ensures that project is not deleted until it is not referenced by any application
  finalizers:
    - argoproj.io/resources-finalizer
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
  name: app-of-apps-$cluster_name
  namespace: $namespace
  finalizers:
    - argoproj.io/resources-finalizer
  labels:
    team: platform
spec:
  project: $cluster_name
  source:
    repoURL: $git_repo
    targetRevision: $git_revision
    path: ./app-of-apps
    helm:
      valueFiles:
        - values-$cluster_name.yaml
      parameters:
        - name: global.spec.source.repoURL
          value: $git_repo
        - name: global.spec.source.targetRevision
          value: $git_revision
        - name: global.spec.values.repoURL
          value: $git_repo
        - name: global.spec.values.targetRevision
          value: $git_revision
        - name: global.clusterName
          value: $cluster_name
        - name: global.domain
          value: $domain
  destination:
    server: https://kubernetes.default.svc
    namespace: $namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: true
EOF
}

function configure_oidc_auth() {
  local context=$1
  local client_secret=$2
  local domain=$3
  local cluster_name=$4

  echo "Configuring OIDC authentication in kubeconfig..."

  # Get cluster info from current context
  local cluster_name_k8s=$(kubectl config view -o jsonpath="{.contexts[?(@.name == \"$context\")].context.cluster}")

  # Create user name with cluster name
  local oidc_user="oidc-$cluster_name"
  local oidc_context="oidc-$cluster_name"

  # Add/Update oidc user with cluster name in the name
  kubectl config set-credentials "$oidc_user" \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=kubectl \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg=--oidc-issuer-url=https://keycloak.$domain/realms/platform \
    --exec-arg=--oidc-client-id=kubernetes \
    --exec-arg=--oidc-client-secret=$client_secret

  # Add/Update oidc context using the same cluster as original context
  kubectl config set-context "$oidc_context" \
    --cluster=$cluster_name_k8s \
    --user="$oidc_user" \
    --namespace=default

  echo "OIDC authentication configured. Use 'kubectl config use-context $oidc_context' to switch to OIDC authentication."
}

function generate_random_secret() {
  # Generate a random string of 32 characters
  openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
}

function secret_exists() {
  local context=$1
  local namespace=$2
  local secret_name=$3

  kubectl get secret "$secret_name" --context "$context" -n "$namespace" &>/dev/null
  return $?
}

# Retrieves or generates a secret value
#
# This function checks if a secret exists in a namespace:
# - If it doesn't exist, generates a random value
# - If it exists, retrieves the value from the specified key
#
# Arguments:
#   $1 - Kubernetes context
#   $2 - Namespace
#   $3 - Secret name
#   $4 - Key in the secret to retrieve (default: 'password')
#
# Example usage:
#   password=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE" "database-superuser" "password")
#
# Returns:
#   The secret value (either retrieved or newly generated)
function get_or_generate_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local key=${4:-"password"}  # Default key is "password" if not specified

  local secret_value
  if ! secret_exists "$context" "$namespace" "$secret_name"; then
    echo "Generating random value for $secret_name" >&2
    secret_value=$(generate_random_secret)
  else
    echo "Secret $secret_name already exists, reusing it" >&2
    secret_value=$(kubectl get secret "$secret_name" --context "$context" -n "$namespace" -o jsonpath="{.data.$key}" | base64 -d)
  fi

  echo "$secret_value"
}

function install_cilium() {
  local context=$1
  local cluster_name=$2

  echo "Installing Cilium ..."
  # helm install cilium cilium/cilium --version 1.17.2 --namespace kube-system

  # Build helm command arguments
  local helm_args=(
    "upgrade"
    "--install"
    "--kube-context" "$context"
    "-n" "kube-system"
    "--wait"
    "-f" "values/defaults/platform/cilium/values.yaml"
    "-f" "values/$cluster_name/platform/cilium/values.yaml"
  )

  # Detect node IPs for ClusterMesh configuration if needed
  # Note: k8sServiceHost is set to "auto" in values files, which automatically
  # reads from the cluster-info ConfigMap - no manual override needed
  local temp_values_file=""
  local node_ip
  node_ip=$(kubectl get nodes --context "$context" -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")

  # Update ClusterMesh IP for the current cluster if ClusterMesh config exists
  # This ensures the ClusterMesh API server is accessible at the correct node IP
  if [ -n "$node_ip" ]; then
    local clustermesh_cluster_name
    clustermesh_cluster_name=$(yq eval '.cluster.name' "values/$cluster_name/platform/cilium/values.yaml" 2>/dev/null || echo "")

    if [ -n "$clustermesh_cluster_name" ] && grep -q "clustermesh:" "values/$cluster_name/platform/cilium/values.yaml" 2>/dev/null; then
      echo "Updating ClusterMesh IP for cluster '$clustermesh_cluster_name' to $node_ip"
      # Create a temporary values file to override the ClusterMesh IP
      temp_values_file=$(mktemp)
      cat > "$temp_values_file" <<EOF
clustermesh:
  config:
    clusters:
    - name: $clustermesh_cluster_name
      ips:
      - $node_ip
EOF
      helm_args+=("-f" "$temp_values_file")
    fi
  fi

  helm_args+=(
    "--repo" "https://helm.cilium.io/"
    "--version" "1.18.5"
    "cilium"
    "cilium"
  )

  helm "${helm_args[@]}"
  local helm_exit_code=$?

  # Clean up temporary values file if it was created
  if [ -n "$temp_values_file" ] && [ -f "$temp_values_file" ]; then
    rm -f "$temp_values_file"
  fi

  # Return the helm exit code
  if [ $helm_exit_code -ne 0 ]; then
    return $helm_exit_code
  fi

  echo "Cilium installation completed."
}

# Variables Initialization
# example: ./scripts/install.sh minikube local https://github.com/kuberise/kuberise.git main 127.0.0.1.nip.io $GITHUB_TOKEN

CONTEXT=${1:-}                                          # example: minikube
CLUSTER_NAME=${2:-onprem}                               # example: onprem, dta, azure etc. (default: onprem)
REPO_URL=${3:-}                                         # example: https://github.com/kuberise/kuberise.git
TARGET_REVISION=${4:-HEAD}                              # example: HEAD, main, master, v1.0.0, release
DOMAIN=${5:-onprem.kuberise.dev}                        # example: onprem.kuberise.dev
CLUSTER_ID=${6:-1}                                      # example: 1, 2, 3, etc. (default: 1)
REPOSITORY_TOKEN=${7:-}

ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
PG_APP_USERNAME=application

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

# Namespace Definitions
NAMESPACE_ARGOCD="argocd"
NAMESPACE_CNPG="postgres"
NAMESPACE_KEYCLOAK="keycloak"
NAMESPACE_BACKSTAGE="backstage"
NAMESPACE_MONITORING="monitoring"
NAMESPACE_CERTMANAGER="cert-manager"
NAMESPACE_EXTERNALDNS="external-dns"
NAMESPACE_PGADMIN="pgadmin"
NAMESPACE_GITEA="gitea"
NAMESPACE_K8SGPT="k8sgpt"

# Warning Message
# echo -n "WARNING: This script will install the cluster '$CLUSTER_NAME' in the Kubernetes context '$CONTEXT'. Please confirm that you want to proceed by typing 'yes':"

# read confirmation
# if [ "$confirmation" != "yes" ]; then
#   echo "Installation aborted."
#   exit 0
# fi

check_required_tools

# Create Namespaces
create_namespace "$CONTEXT" "$NAMESPACE_ARGOCD"
create_namespace "$CONTEXT" "$NAMESPACE_CNPG"
create_namespace "$CONTEXT" "$NAMESPACE_KEYCLOAK"
create_namespace "$CONTEXT" "$NAMESPACE_BACKSTAGE"
create_namespace "$CONTEXT" "$NAMESPACE_MONITORING"
create_namespace "$CONTEXT" "$NAMESPACE_CERTMANAGER"
create_namespace "$CONTEXT" "$NAMESPACE_EXTERNALDNS"
create_namespace "$CONTEXT" "$NAMESPACE_PGADMIN"
create_namespace "$CONTEXT" "$NAMESPACE_GITEA"
create_namespace "$CONTEXT" "$NAMESPACE_K8SGPT"

# Create Secrets if TOKEN is provided
if [ -n "${REPOSITORY_TOKEN}" ]; then
  create_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-platform" "--from-literal=name=kuberise --from-literal=username=x --from-literal=password=$REPOSITORY_TOKEN --from-literal=url=$REPO_URL --from-literal=type=git"
  label_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-platform" "argocd.argoproj.io/secret-type=repository"

  # create_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-green-services" "--from-literal=name=green-services --from-literal=username=x --from-literal=password=$REPOSITORY_TOKEN --from-literal=url=https://github.com/kuberise/green-services.git --from-literal=type=git"
  # label_secret "$CONTEXT" "$NAMESPACE_ARGOCD" "argocd-repo-green-services" "argocd.argoproj.io/secret-type=repository"
  # TODO: Generation of teams and their repositories and projects will be done later
  # TODO: Or get a list of teams and their repositories and create repo secret and project for each of them in a loop
fi

generate_ca_cert_and_key "$CONTEXT"

# Secrets for PostgreSQL
PG_APP_PASSWORD=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_CNPG" "database-app" "password")
create_secret "$CONTEXT" "$NAMESPACE_CNPG" "database-app" "--from-literal=dbname=app --from-literal=host=database-rw --from-literal=username=$PG_APP_USERNAME --from-literal=user=$PG_APP_USERNAME --from-literal=port=5432 --from-literal=password=$PG_APP_PASSWORD --type=kubernetes.io/basic-auth"

PG_SUPERUSER_PASSWORD=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_CNPG" "database-superuser" "password")
create_secret "$CONTEXT" "$NAMESPACE_CNPG" "database-superuser" "--from-literal=dbname=* --from-literal=host=database-rw --from-literal=username=postgres --from-literal=user=postgres --from-literal=port=5432 --from-literal=password=$PG_SUPERUSER_PASSWORD --type=kubernetes.io/basic-auth"

# Secrets for Gitea
create_secret "$CONTEXT" "$NAMESPACE_GITEA" "gitea-admin-secret" "--from-literal=username=gitea_admin --from-literal=password=adminadmin --from-literal=email=admin@gitea.admin --from-literal=passwordMode=keepUpdated --type=kubernetes.io/basic-auth"

# Secrets for K8sGPT
if [ -n "${OPENAI_API_KEY-}" ]; then
  create_secret "$CONTEXT" "$NAMESPACE_K8SGPT" "openai-api" "--from-literal=openai-api-key=$OPENAI_API_KEY"
fi

# Install Cilium before any other components
install_cilium "$CONTEXT" "$CLUSTER_NAME"

# Keycloak and Backstage and Grafana secrets
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "pg-secret" "--from-literal=KC_DB_USERNAME=$PG_APP_USERNAME --from-literal=KC_DB_PASSWORD=$PG_APP_PASSWORD"
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "admin-secret" "--from-literal=KEYCLOAK_ADMIN=admin --from-literal=KEYCLOAK_ADMIN_PASSWORD=$ADMIN_PASSWORD"
create_secret "$CONTEXT" "$NAMESPACE_BACKSTAGE" "pg-secret" "--from-literal=password=$PG_APP_PASSWORD"

create_secret "$CONTEXT" "$NAMESPACE_MONITORING" "grafana-admin" "--from-literal=admin-user=admin --from-literal=admin-password=$ADMIN_PASSWORD --from-literal=ldap-toml="


if [ -n "${CLOUDFLARE_API_TOKEN-}" ]; then
  # Cloudflare API Token Secret for ExternalDNS if CLOUDFLARE_API_TOKEN is provided
  create_secret "$CONTEXT" "$NAMESPACE_EXTERNALDNS" "cloudflare" "--from-literal=cloudflare_api_token=$CLOUDFLARE_API_TOKEN"
  # Cloudflare API Token Secret for Cert-Manager DNS01 Challenge if CLOUDFLARE_API_TOKEN is provided
  create_secret "$CONTEXT" "$NAMESPACE_CERTMANAGER" "cloudflare" "--from-literal=cloudflare_api_token=$CLOUDFLARE_API_TOKEN"
fi


# Create secret for keycloak-operator to connect to Keycloak master realm.
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "keycloak-access" "--from-literal=username=admin --from-literal=password=$ADMIN_PASSWORD"

# Install ArgoCD with custom values and admin password
install_argocd "$CONTEXT" "$NAMESPACE_ARGOCD" "$CLUSTER_NAME" "$ADMIN_PASSWORD" "$DOMAIN"



# Apply ArgoCD project and app of apps configuration
deploy_app_of_apps "$CONTEXT" "$NAMESPACE_ARGOCD" "$CLUSTER_NAME" "$REPO_URL" "$TARGET_REVISION" "$DOMAIN"


# ------------------------------------------------------------
# Generate OAuth2 Client Secrets for Keycloak Authentication
# ------------------------------------------------------------

# Kubernetes OAuth2 Client Secret
echo "Setting up Kubernetes OAuth2 client secret..."
kubernetes_secret=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "kubernetes-oauth2-client-secret" "client-secret")
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "kubernetes-oauth2-client-secret" "--from-literal=client-secret=$kubernetes_secret"
configure_oidc_auth "$CONTEXT" "$kubernetes_secret" "$DOMAIN" "$CLUSTER_NAME"

# Grafana OAuth2 Secret
echo "Setting up Grafana OAuth2 client secret..."
grafana_secret=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "grafana-oauth2-client-secret" "client-secret")
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "grafana-oauth2-client-secret" "--from-literal=client-secret=$grafana_secret"
# Create in monitoring namespace too
create_secret "$CONTEXT" "$NAMESPACE_MONITORING" "grafana-oauth2-client-secret" "--from-literal=client-secret=$grafana_secret"

# PGAdmin OAuth2 Secret
echo "Setting up PGAdmin OAuth2 client secret..."
pgadmin_secret=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "pgadmin-oauth2-client-secret" "client-secret")
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "pgadmin-oauth2-client-secret" "--from-literal=client-secret=$pgadmin_secret"
# Create in pgadmin namespace too
create_secret "$CONTEXT" "$NAMESPACE_PGADMIN" "pgadmin-oauth2-client-secret" "--from-literal=client-secret=$pgadmin_secret"

# OAuth2-Proxy OAuth2 Secret
echo "Setting up OAuth2-Proxy client secret..."
oauth2_proxy_secret=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "oauth2-proxy-oauth2-client-secret" "client-secret")
# Create additional fields needed for oauth2-proxy
cookie_secret=$(generate_random_secret)
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "oauth2-proxy-oauth2-client-secret" "--from-literal=client-secret=$oauth2_proxy_secret --from-literal=client-id=oauth2-proxy --from-literal=cookie-secret=$cookie_secret"

# ArgoCD OAuth2 Secret
echo "Setting up ArgoCD OAuth2 client secret..."
argocd_secret=$(get_or_generate_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "argocd-oauth2-client-secret" "client-secret")
create_secret "$CONTEXT" "$NAMESPACE_KEYCLOAK" "argocd-oauth2-client-secret" "--from-literal=client-secret=$argocd_secret"
ARGOCD_CLIENT_SECRET=$(echo -n "$argocd_secret" | base64)
kubectl patch secret argocd-secret --context "$CONTEXT" -n $NAMESPACE_ARGOCD --patch "
data:
  oidc.keycloak.clientSecret: $ARGOCD_CLIENT_SECRET
"

echo "Installation completed successfully."
