#!/bin/bash

set -euo pipefail

# ── Constants ──────────────────────────────────────────────────────

readonly ARGOCD_CHART_VERSION="9.4.2"
readonly ARGOCD_CHART_REPO="https://argoproj.github.io/argo-helm"
readonly CILIUM_CHART_VERSION="1.19.0"
readonly CILIUM_CHART_REPO="https://helm.cilium.io/"

readonly NAMESPACES=(
  argocd
  postgres
  keycloak
  backstage
  monitoring
  cert-manager
  external-dns
  pgadmin
  gitea
  k8sgpt
)

readonly CA_BUNDLE_NAMESPACES=(
  pgadmin
  monitoring
  argocd
  keycloak
  backstage
  postgres
  cert-manager
  external-dns
)

readonly PG_APP_USERNAME="application"

# ── Logging ────────────────────────────────────────────────────────

# ANSI colors (only when stdout/stderr is a TTY and NO_COLOR is not set)
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET='\033[0m'
  readonly C_INFO='\033[0;36m'   # cyan
  readonly C_WARN='\033[0;33m'   # yellow
  readonly C_ERROR='\033[0;31m' # red
  readonly C_STEP='\033[1;36m'   # bold cyan
else
  readonly C_RESET='' C_INFO='' C_WARN='' C_ERROR='' C_STEP=''
fi

function log_info()  { echo -e "${C_INFO}[INFO]${C_RESET}  $*"; }
function log_warn()  { echo -e "${C_WARN}[WARN]${C_RESET}  $*" >&2; }
function log_error() { echo -e "${C_ERROR}[ERROR]${C_RESET} $*" >&2; }
function log_step()  { echo ""; echo -e "${C_STEP}── $* ──${C_RESET}"; }

# ── Cleanup ────────────────────────────────────────────────────────

TEMP_FILES=()

function cleanup() {
  if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
    for f in "${TEMP_FILES[@]}"; do
      rm -f "$f"
    done
  fi
}
trap cleanup EXIT

function make_temp_file() {
  local f
  f=$(mktemp)
  TEMP_FILES+=("$f")
  echo "$f"
}

# ── Utility Functions ──────────────────────────────────────────────

function generate_random_secret() {
  # Generate a 32-character alphanumeric string.
  # Uses parameter expansion instead of piping to head to avoid SIGPIPE with pipefail.
  local raw
  raw=$(openssl rand -base64 48)
  raw="${raw//[^a-zA-Z0-9]/}"
  echo "${raw:0:32}"
}

# ── Kubernetes Helper Functions ────────────────────────────────────

# Filter out "unchanged" lines from kubectl apply output to reduce noise on re-runs.
# The "|| true" prevents grep from returning exit code 1 when everything is unchanged,
# which would otherwise abort the script under set -eo pipefail.
function filter_unchanged() {
  grep -v ' unchanged$' || true
}

function create_namespace() {
  local context=$1
  local namespace=$2
  kubectl create namespace "$namespace" \
    --context "$context" \
    --dry-run=client -o yaml | \
    kubectl apply --context "$context" -f - | filter_unchanged
}

function create_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  shift 3
  # Remaining arguments (--from-literal, --type, etc.) are passed directly to kubectl
  kubectl create secret generic "$secret_name" \
    --context "$context" \
    -n "$namespace" \
    "$@" \
    --dry-run=client -o yaml | \
    kubectl apply --context "$context" -n "$namespace" -f - | filter_unchanged
}

function label_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local label=$4
  kubectl label secret "$secret_name" "$label" \
    --context "$context" -n "$namespace" --overwrite
}

function secret_exists() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  kubectl get secret "$secret_name" --context "$context" -n "$namespace" &>/dev/null
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
#   password=$(get_or_generate_secret "$CONTEXT" "postgres" "database-superuser" "password")
#
# Returns:
#   The secret value (either retrieved or newly generated) on stdout
function get_or_generate_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  local key=${4:-"password"}

  local secret_value
  if ! secret_exists "$context" "$namespace" "$secret_name"; then
    log_info "Generating random value for $secret_name" >&2
    secret_value=$(generate_random_secret)
  else
    log_info "Secret $secret_name already exists, reusing it" >&2
    secret_value=$(kubectl get secret "$secret_name" --context "$context" -n "$namespace" -o jsonpath="{.data.$key}" | base64 -d)
  fi

  echo "$secret_value"
}

# ── Installation Functions ─────────────────────────────────────────

function generate_ca_cert_and_key() {
  local context=$1

  local dir=".env"
  local cert="$dir/ca.crt"
  local key="$dir/ca.key"
  local ca_bundle="$dir/ca-bundle.crt"

  if [ ! -f "$cert" ] || [ ! -f "$key" ]; then
    log_info "CA certificate/key files do not exist. Generating..."
    mkdir -p "$dir"
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
      -keyout "$key" -out "$cert" -subj "/CN=ca.kuberise.local CA/O=KUBERISE/C=NL"
    log_info "CA certificate and key generated."
  else
    log_info "CA certificate and key already exist."
  fi

  log_info "Creating CA bundle with self-signed and Let's Encrypt certificates..."
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cp "$script_dir/letsencrypt.crt" "$dir/letsencrypt.crt"
  cat "$cert" "$dir/letsencrypt.crt" > "$ca_bundle"
  rm "$dir/letsencrypt.crt"

  # Create TLS secret for cert-manager CA issuer
  kubectl create secret tls ca-key-pair-external \
    --cert="$cert" \
    --key="$key" \
    --namespace="cert-manager" \
    --dry-run=client -o yaml | kubectl apply --namespace="cert-manager" --context="$context" -f - | filter_unchanged

  # Create CA bundle ConfigMap in all relevant namespaces
  for ns in "${CA_BUNDLE_NAMESPACES[@]}"; do
    kubectl create configmap ca-bundle \
      --from-file=ca.crt="$ca_bundle" \
      --namespace="$ns" \
      --dry-run=client -o yaml | kubectl apply --namespace="$ns" --context="$context" -f - | filter_unchanged
  done

  log_info "CA bundle created and ConfigMaps updated in all namespaces."
}

function install_cilium() {
  local context=$1
  local cluster_name=$2

  log_info "Installing Cilium..."

  local helm_args=(
    "upgrade"
    "--install"
    "--kube-context" "$context"
    "-n" "kube-system"
    "--wait"
    "-f" "values/defaults/platform/cilium/values.yaml"
    "-f" "values/$cluster_name/platform/cilium/values.yaml"
  )

  # Dynamic ClusterMesh configuration via temporary values file
  local temp_values_file
  temp_values_file=$(make_temp_file)

  # Get current node IP
  local current_node_ip
  current_node_ip=$(kubectl get nodes --context "$context" -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")

  if [ -n "$current_node_ip" ]; then
    log_info "Detected current node IP: $current_node_ip"
    echo "k8sServiceHost: $current_node_ip" > "$temp_values_file"
  fi

  # Check if ClusterMesh is configured in values
  local clusters_list
  clusters_list=$(yq eval '.clustermesh.config.clusters[].name' "values/$cluster_name/platform/cilium/values.yaml" 2>/dev/null || echo "")

  if [ -n "$clusters_list" ]; then
    log_info "Configuring ClusterMesh..."
    echo "clustermesh:" >> "$temp_values_file"
    echo "  config:" >> "$temp_values_file"
    echo "    clusters:" >> "$temp_values_file"

    for remote_cluster in $clusters_list; do
      local remote_ip=""
      local remote_port="32379"

      if [ "$remote_cluster" == "$cluster_name" ]; then
        remote_ip="$current_node_ip"
      else
        # Try to find IP for remote cluster (assuming k3d context naming convention)
        local remote_context=""
        if kubectl config get-contexts "$remote_cluster" &>/dev/null; then
          remote_context="$remote_cluster"
        elif kubectl config get-contexts "k3d-$remote_cluster" &>/dev/null; then
          remote_context="k3d-$remote_cluster"
        fi

        if [ -n "$remote_context" ]; then
          remote_ip=$(kubectl get nodes --context "$remote_context" -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
          if [ -n "$remote_ip" ]; then
            log_info "  Resolved IP for remote cluster '$remote_cluster' (context: $remote_context): $remote_ip"
          fi
        else
          log_warn "  Could not find context for remote cluster '$remote_cluster'. IP will not be set."
        fi
      fi

      echo "    - name: $remote_cluster" >> "$temp_values_file"
      echo "      port: $remote_port" >> "$temp_values_file"
      if [ -n "$remote_ip" ]; then
        echo "      ips:" >> "$temp_values_file"
        echo "      - $remote_ip" >> "$temp_values_file"
      fi
    done
  fi

  helm_args+=("-f" "$temp_values_file")
  helm_args+=(
    "--repo" "$CILIUM_CHART_REPO"
    "--version" "$CILIUM_CHART_VERSION"
    "cilium"
    "cilium"
  )

  helm "${helm_args[@]}"

  # Restart Cilium agents to ensure they pick up the new config (especially important for ClusterMesh)
  log_info "Restarting Cilium agents..."
  kubectl rollout restart ds/cilium -n kube-system --context "$context"
  kubectl rollout status ds/cilium -n kube-system --context "$context" --timeout=60s

  log_info "Cilium installation completed."
}

function install_argocd() {
  local context=$1
  local cluster_name=$2
  local admin_password=$3
  local domain=$4

  log_info "Installing ArgoCD using Helm..."
  local bcrypt_hash
  bcrypt_hash=$(htpasswd -nbBC 10 "" "$admin_password" | tr -d ':\n' | sed 's/$2y/$2a/')

  helm upgrade \
    --install \
    --kube-context "$context" \
    -n argocd \
    --create-namespace \
    --wait \
    -f "values/defaults/platform/argocd/values.yaml" \
    -f "values/$cluster_name/platform/argocd/values.yaml" \
    --set server.ingress.hostname="argocd.$domain" \
    --set global.domain="argocd.$domain" \
    --set configs.secret.argocdServerAdminPassword="$bcrypt_hash" \
    --repo "$ARGOCD_CHART_REPO" \
    --version "$ARGOCD_CHART_VERSION" \
    argocd argo-cd > /dev/null
}

function deploy_app_of_apps() {
  local context=$1
  local cluster_name=$2
  local git_repo=$3
  local git_revision=$4
  local domain=$5
  local values_repo=${6:-$git_repo}
  local values_revision=${7:-$git_revision}
  local defaults_repo=${8:-$git_repo}
  local defaults_revision=${9:-$git_revision}
  local aoa_name=${10:-app-of-apps}

  # Create ArgoCD project (rendered from the app-of-apps chart to keep a single source of truth, see ADR-0013)
  helm template "$aoa_name-$cluster_name" ./app-of-apps \
    --set global.clusterName="$cluster_name" \
    --show-only templates/AppProject.yaml | \
    kubectl apply --context "$context" -n argocd -f - | filter_unchanged

  # Create app-of-apps
  # No resources-finalizer here: deleting app-of-apps with a finalizer triggers
  # a deep cascade (delete all child apps, each deleting all their k8s resources)
  # that is slow and fragile. The uninstall script handles cleanup explicitly.
  kubectl apply --context "$context" -n argocd -f - <<EOF | filter_unchanged
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $aoa_name-$cluster_name
  namespace: argocd
  labels:
    team: platform
spec:
  project: $cluster_name
  sources:
    - repoURL: $git_repo
      targetRevision: $git_revision
      path: ./app-of-apps
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          - \$values/app-of-apps/values-$cluster_name.yaml
        parameters:
          - name: global.spec.source.repoURL
            value: $git_repo
          - name: global.spec.source.targetRevision
            value: $git_revision
          - name: global.spec.values.repoURL
            value: $values_repo
          - name: global.spec.values.targetRevision
            value: $values_revision
          - name: global.spec.defaults.repoURL
            value: $defaults_repo
          - name: global.spec.defaults.targetRevision
            value: $defaults_revision
          - name: global.clusterName
            value: $cluster_name
          - name: global.domain
            value: $domain
    - repoURL: $values_repo
      targetRevision: $values_revision
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
#      allowEmpty: true # See ADR-0001
EOF
}

function configure_oidc_auth() {
  local context=$1
  local client_secret=$2
  local domain=$3
  local cluster_name=$4

  log_info "Configuring OIDC authentication in kubeconfig..."

  local cluster_name_k8s
  cluster_name_k8s=$(kubectl config view -o jsonpath="{.contexts[?(@.name == \"$context\")].context.cluster}")

  local oidc_user="oidc-$cluster_name"
  local oidc_context="oidc-$cluster_name"

  kubectl config set-credentials "$oidc_user" \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=kubectl \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg="--oidc-issuer-url=https://keycloak.$domain/realms/platform" \
    --exec-arg=--oidc-client-id=kubernetes \
    --exec-arg="--oidc-client-secret=$client_secret"

  kubectl config set-context "$oidc_context" \
    --cluster="$cluster_name_k8s" \
    --user="$oidc_user" \
    --namespace=default

  log_info "OIDC configured. Use 'kubectl config use-context $oidc_context' to switch."
}

# ── Phase Functions ────────────────────────────────────────────────

function create_all_namespaces() {
  for ns in "${NAMESPACES[@]}"; do
    create_namespace "$CONTEXT" "$ns"
  done
}

function configure_repo_access() {
  if [ -n "${TOKEN:-}" ]; then
    create_secret "$CONTEXT" "argocd" "argocd-repo-platform" \
      --from-literal=name=kuberise \
      --from-literal=username=x \
      --from-literal=password="$TOKEN" \
      --from-literal=url="$REPO_URL" \
      --from-literal=type=git
    label_secret "$CONTEXT" "argocd" "argocd-repo-platform" "argocd.argoproj.io/secret-type=repository"

    if [[ "$VALUES_REPO" != "$REPO_URL" ]]; then
      create_secret "$CONTEXT" "argocd" "argocd-repo-values" \
        --from-literal=name=kuberise-values \
        --from-literal=username=x \
        --from-literal=password="$TOKEN" \
        --from-literal=url="$VALUES_REPO" \
        --from-literal=type=git
      label_secret "$CONTEXT" "argocd" "argocd-repo-values" "argocd.argoproj.io/secret-type=repository"
    fi

    if [[ "$DEFAULTS_REPO" != "$REPO_URL" ]] && [[ "$DEFAULTS_REPO" != "$VALUES_REPO" ]]; then
      create_secret "$CONTEXT" "argocd" "argocd-repo-defaults" \
        --from-literal=name=kuberise-defaults \
        --from-literal=username=x \
        --from-literal=password="$TOKEN" \
        --from-literal=url="$DEFAULTS_REPO" \
        --from-literal=type=git
      label_secret "$CONTEXT" "argocd" "argocd-repo-defaults" "argocd.argoproj.io/secret-type=repository"
    fi

    if [ -n "${TEAM_REPOSITORIES:-}" ]; then
      local team_repo_pairs
      IFS=',' read -r -a team_repo_pairs <<< "$TEAM_REPOSITORIES"

      local pair
      for pair in "${team_repo_pairs[@]}"; do
        local team_name
        local team_repo_url
        team_name="${pair%%=*}"
        team_repo_url="${pair#*=}"

        if [ -z "$team_name" ] || [ -z "$team_repo_url" ] || [ "$team_name" = "$team_repo_url" ]; then
          log_warn "Skipping invalid TEAM_REPOSITORIES entry: $pair"
          continue
        fi

        local team_slug
        team_slug=$(echo "$team_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//')

        if [ -z "$team_slug" ]; then
          log_warn "Skipping team with invalid name: $team_name"
          continue
        fi

        local repo_secret_name="argocd-repo-$team_slug"
        create_secret "$CONTEXT" "argocd" "$repo_secret_name" \
          --from-literal=name="$team_slug" \
          --from-literal=username=x \
          --from-literal=password="$TOKEN" \
          --from-literal=url="$team_repo_url" \
          --from-literal=type=git
        label_secret "$CONTEXT" "argocd" "$repo_secret_name" "argocd.argoproj.io/secret-type=repository"

        kubectl apply --context "$CONTEXT" -n argocd -f - <<EOF | filter_unchanged
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: ${CLUSTER_NAME}-${team_slug}
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
    - ${team_repo_url}
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
EOF
      done
    fi
  fi
}

function create_database_secrets() {
  # PostgreSQL application database
  PG_APP_PASSWORD=$(get_or_generate_secret "$CONTEXT" "postgres" "database-app" "password")
  create_secret "$CONTEXT" "postgres" "database-app" \
    --from-literal=dbname=app \
    --from-literal=host=database-rw \
    --from-literal=username="$PG_APP_USERNAME" \
    --from-literal=user="$PG_APP_USERNAME" \
    --from-literal=port=5432 \
    --from-literal=password="$PG_APP_PASSWORD" \
    --type=kubernetes.io/basic-auth

  # PostgreSQL superuser
  PG_SUPERUSER_PASSWORD=$(get_or_generate_secret "$CONTEXT" "postgres" "database-superuser" "password")
  create_secret "$CONTEXT" "postgres" "database-superuser" \
    --from-literal=dbname="*" \
    --from-literal=host=database-rw \
    --from-literal=username=postgres \
    --from-literal=user=postgres \
    --from-literal=port=5432 \
    --from-literal=password="$PG_SUPERUSER_PASSWORD" \
    --type=kubernetes.io/basic-auth

  # Gitea admin (password configurable via GITEA_ADMIN_PASSWORD env var)
  local gitea_password="${GITEA_ADMIN_PASSWORD:-$ADMIN_PASSWORD}"
  create_secret "$CONTEXT" "gitea" "gitea-admin-secret" \
    --from-literal=username=gitea_admin \
    --from-literal=password="$gitea_password" \
    --from-literal=email=admin@gitea.admin \
    --from-literal=passwordMode=keepUpdated \
    --type=kubernetes.io/basic-auth
}

function create_application_secrets() {
  # K8sGPT (optional, requires OPENAI_API_KEY env var)
  if [ -n "${OPENAI_API_KEY:-}" ]; then
    create_secret "$CONTEXT" "k8sgpt" "openai-api" \
      --from-literal=openai-api-key="$OPENAI_API_KEY"
  fi

  # Keycloak database credentials
  create_secret "$CONTEXT" "keycloak" "pg-secret" \
    --from-literal=KC_DB_USERNAME="$PG_APP_USERNAME" \
    --from-literal=KC_DB_PASSWORD="$PG_APP_PASSWORD"

  # Keycloak admin
  create_secret "$CONTEXT" "keycloak" "admin-secret" \
    --from-literal=KEYCLOAK_ADMIN=admin \
    --from-literal=KEYCLOAK_ADMIN_PASSWORD="$ADMIN_PASSWORD"

  # Backstage database
  create_secret "$CONTEXT" "backstage" "pg-secret" \
    --from-literal=password="$PG_APP_PASSWORD"

  # Grafana admin
  create_secret "$CONTEXT" "monitoring" "grafana-admin" \
    --from-literal=admin-user=admin \
    --from-literal=admin-password="$ADMIN_PASSWORD" \
    --from-literal=ldap-toml=

  # Cloudflare (optional, requires CLOUDFLARE_API_TOKEN env var)
  if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
    create_secret "$CONTEXT" "external-dns" "cloudflare" \
      --from-literal=cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
    create_secret "$CONTEXT" "cert-manager" "cloudflare" \
      --from-literal=cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
  fi

  # Keycloak operator access to master realm
  create_secret "$CONTEXT" "keycloak" "keycloak-access" \
    --from-literal=username=admin \
    --from-literal=password="$ADMIN_PASSWORD"
}

function configure_oauth2_clients() {
  # Kubernetes OAuth2 client
  log_info "Setting up Kubernetes OAuth2 client secret..."
  local kubernetes_secret
  kubernetes_secret=$(get_or_generate_secret "$CONTEXT" "keycloak" "kubernetes-oauth2-client-secret" "client-secret")
  create_secret "$CONTEXT" "keycloak" "kubernetes-oauth2-client-secret" \
    --from-literal=client-secret="$kubernetes_secret"
  configure_oidc_auth "$CONTEXT" "$kubernetes_secret" "$DOMAIN" "$CLUSTER_NAME"

  # Grafana OAuth2 client
  log_info "Setting up Grafana OAuth2 client secret..."
  local grafana_secret
  grafana_secret=$(get_or_generate_secret "$CONTEXT" "keycloak" "grafana-oauth2-client-secret" "client-secret")
  create_secret "$CONTEXT" "keycloak" "grafana-oauth2-client-secret" \
    --from-literal=client-secret="$grafana_secret"
  create_secret "$CONTEXT" "monitoring" "grafana-oauth2-client-secret" \
    --from-literal=client-secret="$grafana_secret"

  # PGAdmin OAuth2 client
  log_info "Setting up PGAdmin OAuth2 client secret..."
  local pgadmin_secret
  pgadmin_secret=$(get_or_generate_secret "$CONTEXT" "keycloak" "pgadmin-oauth2-client-secret" "client-secret")
  create_secret "$CONTEXT" "keycloak" "pgadmin-oauth2-client-secret" \
    --from-literal=client-secret="$pgadmin_secret"
  create_secret "$CONTEXT" "pgadmin" "pgadmin-oauth2-client-secret" \
    --from-literal=client-secret="$pgadmin_secret"

  # OAuth2-Proxy client (with persistent cookie secret)
  log_info "Setting up OAuth2-Proxy client secret..."
  local oauth2_proxy_secret
  oauth2_proxy_secret=$(get_or_generate_secret "$CONTEXT" "keycloak" "oauth2-proxy-oauth2-client-secret" "client-secret")
  local cookie_secret
  cookie_secret=$(get_or_generate_secret "$CONTEXT" "keycloak" "oauth2-proxy-oauth2-client-secret" "cookie-secret")
  if [[ -z "$cookie_secret" ]]; then
    cookie_secret=$(generate_random_secret)
  fi
  create_secret "$CONTEXT" "keycloak" "oauth2-proxy-oauth2-client-secret" \
    --from-literal=client-secret="$oauth2_proxy_secret" \
    --from-literal=client-id=oauth2-proxy \
    --from-literal=cookie-secret="$cookie_secret"

  # ArgoCD OAuth2 client
  log_info "Setting up ArgoCD OAuth2 client secret..."
  local argocd_secret
  argocd_secret=$(get_or_generate_secret "$CONTEXT" "keycloak" "argocd-oauth2-client-secret" "client-secret")
  create_secret "$CONTEXT" "keycloak" "argocd-oauth2-client-secret" \
    --from-literal=client-secret="$argocd_secret"
  local argocd_client_secret_b64
  argocd_client_secret_b64=$(echo -n "$argocd_secret" | base64)
  kubectl patch secret argocd-secret --context "$CONTEXT" -n argocd --patch "
data:
  oidc.keycloak.clientSecret: $argocd_client_secret_b64
"
}

# ── Argument Parsing & Validation ──────────────────────────────────

function usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Install kuberise.io platform on a Kubernetes cluster.

Required flags:
  --context CONTEXT        Kubernetes context name
  --repo REPO_URL          Git repository URL

Optional flags:
  --cluster NAME           Cluster name (default: onprem)
  --revision REV           Branch, tag, or commit SHA (default: HEAD)
  --domain DOMAIN          Base domain for services (default: onprem.kuberise.dev)
  --token TOKEN            Git token for private repositories
  --values-repo URL        Git repo for cluster values (default: same as --repo)
  --values-revision REV    Revision for values repo (default: same as --revision)
  --defaults-repo URL      Git repo for default values (default: same as --repo)
  --defaults-revision REV  Revision for defaults repo (default: same as --revision)
  --name NAME              App-of-apps name suffix (default: app-of-apps)
  -h, --help               Show this help message

Environment variables:
  ADMIN_PASSWORD           Admin password for platform services (default: admin)
  GITEA_ADMIN_PASSWORD     Gitea admin password (default: value of ADMIN_PASSWORD)
  CLOUDFLARE_API_TOKEN     Cloudflare API token for ExternalDNS and cert-manager
  OPENAI_API_KEY           OpenAI API key for K8sGPT
  TEAM_REPOSITORIES        Comma-separated team-to-repo map (team=repoURL,team2=repoURL)

Example:
  $0 --context k3d-dev --cluster dev-app-onprem-one \\
     --repo https://github.com/kuberise/kuberise.io.git \\
     --revision main --domain dev.kuberise.dev

  $0 --context k3d-dev --cluster dev-app-onprem-one \\
     --repo https://github.com/kuberise/kuberise.io.git \\
     --revision main --domain dev.kuberise.dev \\
     --token \$GITHUB_TOKEN
EOF
}

function parse_args() {
  CONTEXT=""
  CLUSTER_NAME="onprem"
  REPO_URL=""
  TARGET_REVISION="HEAD"
  DOMAIN="onprem.kuberise.dev"
  TOKEN=""
  VALUES_REPO=""
  VALUES_REVISION=""
  DEFAULTS_REPO=""
  DEFAULTS_REVISION=""
  APP_OF_APPS_NAME=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --context)            CONTEXT="$2";            shift 2 ;;
      --cluster)            CLUSTER_NAME="$2";       shift 2 ;;
      --repo)               REPO_URL="$2";           shift 2 ;;
      --revision)           TARGET_REVISION="$2";    shift 2 ;;
      --domain)             DOMAIN="$2";             shift 2 ;;
      --token)              TOKEN="$2";              shift 2 ;;
      --values-repo)        VALUES_REPO="$2";        shift 2 ;;
      --values-revision)    VALUES_REVISION="$2";    shift 2 ;;
      --defaults-repo)      DEFAULTS_REPO="$2";      shift 2 ;;
      --defaults-revision)  DEFAULTS_REVISION="$2";  shift 2 ;;
      --name)               APP_OF_APPS_NAME="$2";   shift 2 ;;
      --help|-h)            usage; exit 0 ;;
      *)                    log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
  VALUES_REPO="${VALUES_REPO:-$REPO_URL}"
  VALUES_REVISION="${VALUES_REVISION:-$TARGET_REVISION}"
  DEFAULTS_REPO="${DEFAULTS_REPO:-$REPO_URL}"
  DEFAULTS_REVISION="${DEFAULTS_REVISION:-$TARGET_REVISION}"
  APP_OF_APPS_NAME="${APP_OF_APPS_NAME:-app-of-apps}"
}

function validate() {
  check_required_tools

  if [[ -z "$CONTEXT" ]]; then
    log_error "Missing required flag: --context"
    usage
    exit 1
  fi

  if [[ -z "$REPO_URL" ]]; then
    log_error "Missing required flag: --repo"
    usage
    exit 1
  fi

  if [[ ! -d "values/$CLUSTER_NAME" ]]; then
    log_error "Cluster values directory 'values/$CLUSTER_NAME' does not exist."
    log_error "Available clusters: $(ls values/)"
    exit 1
  fi

  if ! kubectl cluster-info --context "$CONTEXT" &>/dev/null; then
    log_error "Cannot connect to cluster using context '$CONTEXT'."
    exit 1
  fi

  if [[ "$ADMIN_PASSWORD" == "admin" ]]; then
    log_warn "Using default admin password 'admin'. Set ADMIN_PASSWORD env var for production use."
  fi
}

function check_required_tools() {
  local required_tools=("kubectl" "helm" "htpasswd" "openssl" "cilium" "yq")
  for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
      log_error "$tool could not be found, please install it."
      exit 1
    fi
  done
}

# ── Extension Point ────────────────────────────────────────────────

# No-op by default. Pro install script can source install.sh and override
# this function to deploy additional app-of-apps layers (pro, client).
function deploy_additional_layers() {
  :
}

# ── Main ───────────────────────────────────────────────────────────

function main() {
  parse_args "$@"
  validate

  log_step "Creating namespaces"
  create_all_namespaces

  log_step "Configuring repository access"
  configure_repo_access

  log_step "Generating CA certificates"
  generate_ca_cert_and_key "$CONTEXT"

  log_step "Creating database secrets"
  create_database_secrets

  log_step "Installing Cilium"
  install_cilium "$CONTEXT" "$CLUSTER_NAME"

  log_step "Creating application secrets"
  create_application_secrets

  log_step "Installing ArgoCD"
  install_argocd "$CONTEXT" "$CLUSTER_NAME" "$ADMIN_PASSWORD" "$DOMAIN"

  log_step "Deploying app-of-apps"
  deploy_app_of_apps "$CONTEXT" "$CLUSTER_NAME" "$REPO_URL" "$TARGET_REVISION" "$DOMAIN" \
    "$VALUES_REPO" "$VALUES_REVISION" "$DEFAULTS_REPO" "$DEFAULTS_REVISION" "$APP_OF_APPS_NAME"

  deploy_additional_layers

  log_step "Configuring OAuth2 clients"
  configure_oauth2_clients

  echo ""
  log_info "Installation completed successfully."
}

main "$@"
