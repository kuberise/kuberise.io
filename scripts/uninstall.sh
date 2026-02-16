#!/bin/bash

set -euo pipefail

# Prevent kubectl operations from hanging indefinitely when webhooks/APIServices
# are unhealthy during teardown.
readonly KUBECTL_REQUEST_TIMEOUT="${KUBECTL_REQUEST_TIMEOUT:-15s}"

# Wrap kubectl so every call gets a bounded request timeout and uses the target context.
# CONTEXT must be set (by parse_args) before any kubectl invocation.
function kubectl() {
  command kubectl --request-timeout="$KUBECTL_REQUEST_TIMEOUT" --context "${CONTEXT:?}" "$@"
}

# ── Logging ────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET='\033[0m'
  readonly C_INFO='\033[0;36m'   # cyan
  readonly C_WARN='\033[0;33m'   # yellow
  readonly C_ERROR='\033[0;31m'  # red
  readonly C_STEP='\033[1;36m'   # bold cyan
else
  readonly C_RESET='' C_INFO='' C_WARN='' C_ERROR='' C_STEP=''
fi

function log_info()  { echo -e "${C_INFO}[INFO]${C_RESET}  $*"; }
function log_warn()  { echo -e "${C_WARN}[WARN]${C_RESET}  $*" >&2; }
function log_error() { echo -e "${C_ERROR}[ERROR]${C_RESET} $*" >&2; }
function log_step()  { echo ""; echo -e "${C_STEP}── $* ──${C_RESET}"; }

# ── Constants ──────────────────────────────────────────────────────

# All namespaces that kuberise may create (via install.sh or ArgoCD apps).
# Excludes kube-system since it is a core Kubernetes namespace.
# Components that deploy into kube-system (cilium, metrics-server,
# aws-lb-controller) are cleaned up via helm uninstall, not namespace deletion.
readonly KUBERISE_NAMESPACES=(
  # Platform Core
  argocd
  backstage
  gitea
  hello
  ingresses
  raw
  teams-namespaces

  # Data Services
  postgres
  pgadmin
  redis
  minio
  object-storage

  # Network Services
  metallb
  external-dns
  external-dns-sigs
  internal-dns
  ingress-nginx-external
  ingress-nginx-internal

  # Security & Auth
  keycloak
  cert-manager
  kyverno
  external-secrets
  sealed-secrets
  vault
  secrets-manager
  neuvector

  # Monitoring
  monitoring

  # AI Tools
  ollama
  k8sgpt

  # CI/CD
  keda
  tekton-operator
  tekton-pipelines

  # Multi-cluster / management
  cattle-system
  vcluster

  # Example applications
  frontend
  backend
  opencost
)

# Helm releases installed in kube-system by install.sh (not managed by ArgoCD).
#
# NOTE: Cilium is intentionally NOT uninstalled here. Cilium is the CNI
# (Container Network Interface) - the cluster's networking layer. Removing it
# breaks all pod networking, causing namespace deletions to hang (finalizer pods
# can't start) and new pods to fail with "unable to connect to Cilium agent".
# If you need to fully destroy the cluster, use k3d/kind/cloud-provider tools
# to delete the cluster itself.
readonly KUBE_SYSTEM_HELM_RELEASES=(
  # Releases that are safe to remove from kube-system
  # (add entries here as "release-name" if needed in the future)
)

# ── Argument Parsing ───────────────────────────────────────────────

function usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Uninstall kuberise.io platform from a Kubernetes cluster.

Required flags:
  --context CONTEXT        Kubernetes context name
  --cluster NAME           Cluster name (must match the name used during install)

Optional flags:
  --yes, -y                Skip interactive confirmation prompt
  -h, --help               Show this help message

Example:
  $0 --context k3d-dev --cluster dev-app-onprem-one
EOF
}

function parse_args() {
  CONTEXT=""
  CLUSTER_NAME=""
  ASSUME_YES=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --context)      CONTEXT="$2";      shift 2 ;;
      --cluster)      CLUSTER_NAME="$2"; shift 2 ;;
      --yes|-y)       ASSUME_YES=true;   shift ;;
      --help|-h)      usage; exit 0 ;;
      *)              log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

function validate() {
  if [[ -z "$CONTEXT" ]]; then
    log_error "Missing required flag: --context"
    usage
    exit 1
  fi

  if [[ -z "$CLUSTER_NAME" ]]; then
    log_error "Missing required flag: --cluster"
    usage
    exit 1
  fi

  if ! kubectl cluster-info &>/dev/null; then
    log_error "Cannot connect to cluster using context '$CONTEXT'."
    exit 1
  fi
}

# Build the namespace deletion target list from:
# 1) Known kuberise namespaces
# 2) ArgoCD application destinations and managed resource namespaces
#
# This makes uninstall resilient when cluster variants (for example shared
# clusters) enable additional apps/namespaces beyond the static defaults.
function collect_uninstall_namespaces() {
  local candidates
  local discovered

  candidates=("${KUBERISE_NAMESPACES[@]}")
  discovered=$(kubectl get applications -n argocd \
    -o jsonpath='{range .items[*]}{.spec.destination.namespace}{"\n"}{range .status.resources[*]}{.namespace}{"\n"}{end}{end}' 2>/dev/null || true)

  if [[ -n "$discovered" ]]; then
    while IFS= read -r ns; do
      [[ -z "$ns" ]] && continue
      case "$ns" in
        kube-system|kube-public|kube-node-lease|default)
          continue
          ;;
      esac
      candidates+=("$ns")
    done <<< "$discovered"
  fi

  # Unique + stable order. Use process substitution so the while runs in this
  # shell (not a subshell) and UNINSTALL_NAMESPACES is populated.
  UNINSTALL_NAMESPACES=()
  while IFS= read -r ns; do
    [[ -z "$ns" ]] && continue
    UNINSTALL_NAMESPACES+=("$ns")
  done < <(printf '%s\n' "${candidates[@]}" | awk 'NF' | sort -u)
}

# ── Uninstall Functions ────────────────────────────────────────────

function remove_app_of_apps() {
  # Step 1: Delete all app-of-apps Applications.
  # In OSS there is one (app-of-apps-platform). In pro/client setups
  # there can be up to three (app-of-apps-pro, app-of-apps-acme, etc.).
  # No finalizer per ADR-0018, so deletion is instant.
  log_info "Deleting app-of-apps ArgoCD application(s)..."
  local aoa_apps
  aoa_apps=$(kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
  for app in $aoa_apps; do
    if [[ "$app" == app-of-apps-* ]]; then
      log_info "  Deleting $app"
      kubectl delete -n argocd application "$app" --ignore-not-found 2>/dev/null || true
    fi
  done

  # Step 2: Delete all remaining child applications at once, then wait
  delete_all_applications

  # Step 3: Remove AppProject finalizers so delete can succeed, then delete.
  log_info "Deleting ArgoCD project..."
  kubectl patch appproject kuberise -n argocd \
    --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
  kubectl delete -n argocd appproject kuberise --ignore-not-found 2>/dev/null || true
}

function get_application_names() {
  kubectl get applications -n argocd -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo ""
}

# Delete all ArgoCD Applications in a single batch, poll until they are gone,
# and handle stuck applications by clearing operator finalizers on their managed
# resources. This avoids the ordering problem where deleting a service before
# its config app causes operator finalizers to deadlock (e.g., keycloak deleted
# before keycloak-config, so the keycloak-operator can't clean up CRDs).
function delete_all_applications() {
  local apps
  apps=$(get_application_names)

  if [[ -z "$apps" ]]; then
    log_info "No remaining ArgoCD applications to delete."
    return
  fi

  local count
  count=$(echo "$apps" | wc -w | tr -d ' ')
  log_info "Deleting all $count ArgoCD application(s) at once..."
  kubectl delete applications --all -n argocd --wait=false 2>/dev/null || true

  # Poll until all applications are gone or timeout is reached
  local timeout=30
  local elapsed=0
  local interval=5

  while [[ $elapsed -lt $timeout ]]; do
    apps=$(get_application_names)

    if [[ -z "$apps" ]]; then
      log_info "All ArgoCD applications deleted successfully."
      return
    fi

    count=$(echo "$apps" | wc -w | tr -d ' ')
    log_info "Waiting for $count application(s) to finish deleting... (${elapsed}s/${timeout}s)"
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  # Timeout reached: some applications are stuck on finalizers
  apps=$(get_application_names)
  count=$(echo "$apps" | wc -w | tr -d ' ')
  log_warn "$count application(s) still stuck after ${timeout}s. Clearing stuck resources..."

  # First pass: clear operator finalizers on managed CRD resources.
  # This is the root cause of most hangs - operators can't clean up their
  # CRD instances because the service they depend on was already deleted.
  for app in $apps; do
    clear_stuck_managed_resources "$app"
  done

  # Wait for ArgoCD to process the unblocked deletions
  log_info "Waiting for ArgoCD to process resource cleanup..."
  sleep 10

  # Second pass: force-clear finalizers on any Applications still stuck
  apps=$(get_application_names)
  for app in $apps; do
    log_warn "  Force-clearing ArgoCD finalizers on application: $app"
    kubectl patch application "$app" -n argocd \
      --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
  done

  # Final check
  sleep 5
  apps=$(get_application_names)
  if [[ -z "$apps" ]]; then
    log_info "All ArgoCD applications deleted successfully."
  else
    log_warn "Some applications may still be terminating."
  fi
}

# Clear operator-managed finalizers on CRD instances that are managed by a
# stuck ArgoCD Application. This unblocks ArgoCD's resources-finalizer cascade.
#
# The typical deadlock: an operator (e.g., keycloak-operator) sets finalizers on
# its CRD instances (e.g., KeycloakRealm). During uninstall, if the operator's
# target service is deleted first, the operator can't complete cleanup, so its
# finalizers never clear, which blocks the ArgoCD Application deletion.
#
# This function reads the Application's status.resources to find exactly which
# resources are managed, checks if any are stuck in Terminating, and clears
# their finalizers.
function clear_stuck_managed_resources() {
  local app_name=$1
  log_info "  Checking managed resources for stuck application: $app_name"

  # ArgoCD Application status.resources lists all managed resources with
  # group, kind, namespace, and name.
  local resources
  resources=$(kubectl get application "$app_name" -n argocd \
    -o jsonpath='{range .status.resources[*]}{.group}{"\t"}{.kind}{"\t"}{.namespace}{"\t"}{.name}{"\n"}{end}' 2>/dev/null || echo "")

  while IFS=$'\t' read -r group kind ns name; do
    [[ -z "$kind" || -z "$name" ]] && continue
    # Skip core API resources (empty group) except PVC and PV, which often get
    # stuck in Terminating when the workload (e.g. CloudNativePG) is removed first
    if [[ -z "$group" ]]; then
      [[ "$kind" != "PersistentVolumeClaim" && "$kind" != "PersistentVolume" ]] && continue
    fi

    # Use kind.group for CRDs; core API uses kind only
    local resource_ref="${kind}.${group}"
    [[ -z "$group" ]] && resource_ref="$kind"

    # Check if this resource is stuck in Terminating (has deletionTimestamp).
    # Cluster-scoped resources (PersistentVolume, ClusterRole, etc.) have an
    # empty namespace in ArgoCD's status.resources; skip the -n flag for those.
    local deletion_ts
    if [[ -z "$ns" ]]; then
      deletion_ts=$(kubectl get "$resource_ref" "$name" \
        -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
    else
      deletion_ts=$(kubectl get "$resource_ref" "$name" -n "$ns" \
        -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
    fi

    if [[ -n "$deletion_ts" ]]; then
      if [[ -z "$ns" ]]; then
        log_info "    Clearing finalizers on ${kind}/${name}"
        kubectl patch "$resource_ref" "$name" \
          --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
      else
        log_info "    Clearing finalizers on ${kind}/${name} in namespace ${ns}"
        kubectl patch "$resource_ref" "$name" -n "$ns" \
          --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
      fi
    fi
  done <<< "$resources"
}

# Clear spec.finalizers on a namespace stuck in Terminating.
# After ArgoCD and operators are removed, their namespace-level finalizers can
# never be processed, so the namespace hangs in Terminating indefinitely. This
# sends a minimal Namespace object with an empty finalizers list to the finalize
# subresource API to force removal.
function clear_namespace_finalizers() {
  local ns=$1
  log_warn "  Force-clearing spec.finalizers on namespace: $ns"
  local payload='{"apiVersion":"v1","kind":"Namespace","metadata":{"name":"'"$ns"'"},"spec":{"finalizers":[]}}'
  echo "$payload" | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - 2>/dev/null || true
}

# Clear finalizers on PVCs and PVs stuck in Terminating. Namespaces often hang
# because PVCs (and their bound PVs) have protection finalizers that never
# complete once the workload (e.g. CloudNativePG Cluster) is gone. Clear PVCs
# first so they can be removed, then PVs (pv-protection waits for the claim).
function clear_stuck_pvcs_and_pvs() {
  local count_pvc=0
  local count_pv=0

  for ns in "${UNINSTALL_NAMESPACES[@]}"; do
    local names
    names=$(kubectl get pvc -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    for pvc in $names; do
      [[ -z "$pvc" ]] && continue
      local dt
      dt=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
      if [[ -n "$dt" ]]; then
        log_info "  Clearing finalizers on PVC $ns/$pvc"
        kubectl patch pvc "$pvc" -n "$ns" --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        count_pvc=$((count_pvc + 1))
      fi
    done
  done

  local pv_names
  pv_names=$(kubectl get pv -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
  for pv in $pv_names; do
    [[ -z "$pv" ]] && continue
    local dt
    dt=$(kubectl get pv "$pv" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
    if [[ -n "$dt" ]]; then
      log_info "  Clearing finalizers on PV $pv"
      kubectl patch pv "$pv" --type merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
      count_pv=$((count_pv + 1))
    fi
  done

  if [[ $count_pvc -gt 0 || $count_pv -gt 0 ]]; then
    log_info "Cleared finalizers on $count_pvc PVC(s) and $count_pv PV(s) stuck in Terminating."
  fi
}

function uninstall_argocd() {
  log_info "Uninstalling ArgoCD via Helm..."
  helm uninstall argocd --kube-context "$CONTEXT" -n argocd 2>/dev/null || true
}

function uninstall_kube_system_releases() {
  for release in "${KUBE_SYSTEM_HELM_RELEASES[@]}"; do
    log_info "Uninstalling Helm release '$release' from kube-system..."
    helm uninstall "$release" --kube-context "$CONTEXT" -n kube-system 2>/dev/null || true
  done
}

# Delete webhook configs whose service references a namespace being uninstalled.
# $1 = resource type (validatingwebhookconfiguration | mutatingwebhookconfiguration)
# $2 = display name for logging
function delete_orphaned_webhooks() {
  local type=$1
  local label=$2
  local names
  names=$(kubectl get "$type" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

  for name in $names; do
    local svc_namespaces
    svc_namespaces=$(kubectl get "$type" "$name" \
      -o jsonpath='{range .webhooks[*]}{.clientConfig.service.namespace}{"\n"}{end}' 2>/dev/null || echo "")
    for ns in "${UNINSTALL_NAMESPACES[@]}"; do
      if echo "$svc_namespaces" | grep -qxF "$ns"; then
        log_info "  Deleting $label: $name (references namespace $ns)"
        kubectl delete "$type" "$name" --ignore-not-found 2>/dev/null || true
        break
      fi
    done
  done
}

function cleanup_cluster_scoped_resources() {
  # Orphaned webhooks block future operations (e.g., ingress-nginx rejects Ingress creation).
  log_info "Cleaning up orphaned webhook configurations..."
  delete_orphaned_webhooks validatingwebhookconfiguration "ValidatingWebhookConfiguration"
  delete_orphaned_webhooks mutatingwebhookconfiguration "MutatingWebhookConfiguration"
}

function delete_namespaces() {
  for ns in "${UNINSTALL_NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &>/dev/null; then
      log_info "Deleting namespace: $ns"
      kubectl delete namespace "$ns" --wait=false 2>/dev/null || true
    fi
  done
}

# Wait for namespace deletion and force-delete any that get stuck in
# Terminating. Namespaces get stuck when resources inside them have
# operator-managed finalizers that can't complete (e.g., the operator or its
# target service was already deleted). This clears the namespace's
# spec.finalizers via the finalize API to force removal.
function cleanup_stuck_namespaces() {
  # Unblock PVCs and PVs stuck in Terminating (e.g. after CloudNativePG Cluster
  # is removed); otherwise namespaces can hang waiting for them.
  log_info "Clearing finalizers on any PVCs and PVs stuck in Terminating..."
  clear_stuck_pvcs_and_pvs

  # Collect namespaces that are currently in Terminating state
  local stuck_namespaces=()
  for ns in "${UNINSTALL_NAMESPACES[@]}"; do
    local phase
    phase=$(kubectl get namespace "$ns" \
      -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
    if [[ "$phase" == "Terminating" ]]; then
      stuck_namespaces+=("$ns")
    fi
  done

  if [[ ${#stuck_namespaces[@]} -eq 0 ]]; then
    log_info "All namespaces deleted or deleting normally."
    return
  fi

  local count=${#stuck_namespaces[@]}
  log_info "Waiting for $count namespace(s) still in Terminating state..."

  # Wait with timeout for namespaces to finish deleting on their own
  local timeout=60
  local elapsed=0
  local interval=5

  while [[ $elapsed -lt $timeout ]]; do
    local still_stuck=()
    for ns in "${stuck_namespaces[@]}"; do
      local phase
      phase=$(kubectl get namespace "$ns" \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
      if [[ "$phase" == "Terminating" ]]; then
        still_stuck+=("$ns")
      fi
    done

    if [[ ${#still_stuck[@]} -eq 0 ]]; then
      log_info "All namespaces deleted successfully."
      return
    fi

    stuck_namespaces=("${still_stuck[@]}")
    log_info "  ${#stuck_namespaces[@]} namespace(s) still terminating... (${elapsed}s/${timeout}s)"
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  # Force-delete stuck namespaces by clearing spec.finalizers
  log_warn "${#stuck_namespaces[@]} namespace(s) stuck after ${timeout}s. Force-clearing finalizers..."
  for ns in "${stuck_namespaces[@]}"; do
    clear_namespace_finalizers "$ns"
  done
}

# Remove all kubeconfig entries related to this cluster:
# 1. OIDC context + user created by install.sh (oidc-$CLUSTER_NAME)
# 2. The cluster context itself ($CONTEXT) and its cluster/user entries
#
# Cluster and user entries are only removed when no other context still
# references them, so shared entries (e.g., a cluster used by multiple
# contexts) are preserved.
#
# Uses 'command kubectl' directly because config operations are local file
# edits that don't need --context or --request-timeout from the wrapper.
function cleanup_kubeconfig() {
  log_info "Cleaning up kubeconfig entries..."

  local oidc_user="oidc-$CLUSTER_NAME"
  local oidc_context="oidc-$CLUSTER_NAME"

  # ── OIDC entries (created by install.sh's configure_oidc_auth) ──

  if command kubectl config get-contexts "$oidc_context" &>/dev/null; then
    command kubectl config delete-context "$oidc_context" 2>/dev/null || true
    log_info "  Deleted kubeconfig context: $oidc_context"
  fi

  if command kubectl config view -o jsonpath="{.users[?(@.name==\"$oidc_user\")].name}" 2>/dev/null | grep -qF "$oidc_user"; then
    command kubectl config delete-user "$oidc_user" 2>/dev/null || true
    log_info "  Deleted kubeconfig user: $oidc_user"
  fi

  # ── Cluster context and associated entries ──

  if ! command kubectl config get-contexts "$CONTEXT" &>/dev/null; then
    log_info "  Context '$CONTEXT' not found in kubeconfig, skipping."
    return
  fi

  # Read cluster and user names from the context before deleting it
  local ctx_cluster ctx_user
  ctx_cluster=$(command kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CONTEXT\")].context.cluster}" 2>/dev/null || echo "")
  ctx_user=$(command kubectl config view -o jsonpath="{.contexts[?(@.name==\"$CONTEXT\")].context.user}" 2>/dev/null || echo "")

  command kubectl config delete-context "$CONTEXT" 2>/dev/null || true
  log_info "  Deleted kubeconfig context: $CONTEXT"

  # Delete the cluster entry only if no other context still references it
  if [[ -n "$ctx_cluster" ]]; then
    local other_refs
    other_refs=$(command kubectl config view -o jsonpath="{.contexts[?(@.context.cluster==\"$ctx_cluster\")].name}" 2>/dev/null || echo "")
    if [[ -z "$other_refs" ]]; then
      command kubectl config delete-cluster "$ctx_cluster" 2>/dev/null || true
      log_info "  Deleted kubeconfig cluster: $ctx_cluster"
    else
      log_info "  Kept kubeconfig cluster '$ctx_cluster' (still referenced by other contexts)"
    fi
  fi

  # Delete the user entry only if no other context still references it
  if [[ -n "$ctx_user" ]]; then
    local other_refs
    other_refs=$(command kubectl config view -o jsonpath="{.contexts[?(@.context.user==\"$ctx_user\")].name}" 2>/dev/null || echo "")
    if [[ -z "$other_refs" ]]; then
      command kubectl config delete-user "$ctx_user" 2>/dev/null || true
      log_info "  Deleted kubeconfig user: $ctx_user"
    else
      log_info "  Kept kubeconfig user '$ctx_user' (still referenced by other contexts)"
    fi
  fi

  # If current-context was pointing to a deleted context, unset it
  local current
  current=$(command kubectl config current-context 2>/dev/null || echo "")
  if [[ "$current" == "$CONTEXT" || "$current" == "$oidc_context" ]]; then
    command kubectl config unset current-context 2>/dev/null || true
    log_info "  Unset current-context (was pointing to deleted context)"
  fi
}

# ── Main ───────────────────────────────────────────────────────────

function main() {
  parse_args "$@"
  validate
  collect_uninstall_namespaces

  echo ""
  if [[ "$ASSUME_YES" != true ]]; then
    read -p "This script will remove the '$CLUSTER_NAME' cluster installation from the '$CONTEXT' Kubernetes context.

It will:
  - Delete the app-of-apps ArgoCD application and project
  - Uninstall ArgoCD Helm release
  - Remove orphaned webhook configurations (cluster-scoped)
  - Delete kuberise-managed namespaces (including ArgoCD-discovered namespaces)
  - Remove cluster context and OIDC entries from kubeconfig (if present)
  - Cilium (CNI) will NOT be removed (the cluster needs it to function)

Are you sure you want to continue? (yes/no): " answer

    if [[ "$answer" != "yes" ]]; then
      echo "Aborting uninstallation."
      exit 0
    fi
  fi

  log_step "Removing app-of-apps"
  remove_app_of_apps

  log_step "Uninstalling ArgoCD"
  uninstall_argocd

  if [[ ${#KUBE_SYSTEM_HELM_RELEASES[@]} -gt 0 ]]; then
    log_step "Uninstalling kube-system Helm releases"
    uninstall_kube_system_releases
  fi

  log_step "Cleaning up cluster-scoped resources"
  cleanup_cluster_scoped_resources

  log_step "Deleting namespaces"
  delete_namespaces

  log_step "Checking for stuck namespaces"
  cleanup_stuck_namespaces

  log_step "Cleaning up kubeconfig"
  cleanup_kubeconfig

  echo ""
  log_info "kuberise uninstalled successfully."
}

main "$@"
