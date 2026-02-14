# Install Script Reference

This document describes the structure, flow, and implementation details of `scripts/install.sh`, the bootstrap script that deploys the kuberise.io platform on a Kubernetes cluster. See [Installation](public/1.getting-started/2.installation.md) for user-facing usage.

## Overview

The script is a Bash orchestrator that:

- Takes a bare (or existing) Kubernetes cluster and prepares it for GitOps
- Creates namespaces, secrets, and CA material
- Installs Cilium (CNI) and Argo CD via Helm
- Deploys the root app-of-apps Argo CD Application so that all other platform components are managed declaratively

After the script finishes, Argo CD owns the rest of the deployment. The script is **idempotent**: safe to run multiple times. Design rationale is recorded in [ADR-0016](adr/0016-install-script-improvements.md) and [ADR-0017](adr/0017-bash-install-script-over-custom-cli.md).

## Prerequisites and Invocation

**Required tools:** `kubectl`, `helm`, `htpasswd`, `openssl`, `cilium`, `yq`. The script validates these in `check_required_tools` and exits if any are missing.

**Required flags:** `--context`, `--repo`. Optional: `--cluster`, `--revision`, `--domain`, `--token`. Run from the repository root so that paths like `values/`, `app-of-apps/`, and `scripts/letsencrypt.crt` resolve correctly.

**Entry point:** The last line of the script is `main "$@"`, which passes all command-line arguments to the `main` function.

---

## Script Structure

The script is organized into sections with comment headers:

| Section | Lines (approx.) | Purpose |
|--------|------------------|---------|
| Shebang and options | 1–3 | `#!/bin/bash`, `set -euo pipefail` |
| Constants | 5–36 | Chart versions, repo URLs, namespace lists |
| Logging | 37–42 | `log_info`, `log_warn`, `log_error`, `log_step` |
| Cleanup | 43–62 | Temp file tracking and `EXIT` trap |
| Utility functions | 63–73 | `generate_random_secret` |
| Kubernetes helpers | 74–154 | Namespace/secret helpers, `get_or_generate_secret` |
| Installation functions | 156–401 | CA, Cilium, Argo CD, app-of-apps, OIDC |
| Phase functions | 403–428 | High-level steps that use the helpers |
| Argument parsing and validation | 430–522 | `usage`, `parse_args`, `validate`, `check_required_tools` |
| Main | 664–699 | Orchestrates all phases; `main "$@"` at end |

---

## Execution Flow (Main Steps)

`main()` runs the following phases in order:

1. **Parse and validate**  
   `parse_args "$@"` then `validate`. Exits if required flags are missing, cluster is unreachable, or `values/$CLUSTER_NAME` does not exist.

2. **Creating namespaces**  
   `create_all_namespaces` creates each namespace in the `NAMESPACES` array via `create_namespace`.

3. **Configuring repository access**  
   `configure_repo_access` creates the Argo CD repository secret and labels it if `--token` (or `TOKEN`) is set.

4. **Generating CA certificates**  
   `generate_ca_cert_and_key` creates or reuses a CA, builds a CA bundle, creates the cert-manager TLS secret and CA-bundle ConfigMaps in `CA_BUNDLE_NAMESPACES`.

5. **Creating database secrets**  
   `create_database_secrets` creates PostgreSQL app/superuser and Gitea admin secrets; uses `get_or_generate_secret` so values persist across re-runs.

6. **Installing Cilium**  
   `install_cilium` runs Helm with default and cluster-specific values, optional ClusterMesh temp values, then restarts the Cilium DaemonSet.

7. **Creating application secrets**  
   `create_application_secrets` creates secrets for K8sGPT, Keycloak, Backstage, Grafana, optional Cloudflare, and Keycloak operator access.

8. **Installing Argo CD**  
   `install_argocd` runs Helm to install/upgrade Argo CD with merged values and admin password bcrypt hash.

9. **Deploying app-of-apps**  
   `deploy_app_of_apps` creates the Argo CD AppProject (from the app-of-apps chart) and the root Application manifest pointing at the repo and `values-$CLUSTER_NAME.yaml`.

10. **Configuring OAuth2 clients**  
    `configure_oauth2_clients` creates/reuses OAuth2 client secrets for Kubernetes, Grafana, PGAdmin, OAuth2-Proxy, and Argo CD, and configures OIDC in kubeconfig.

Each phase is preceded by `log_step "..."` so the run is easy to follow. The script exits on first failure (`set -e`); the `EXIT` trap ensures temp files are removed.

---

## Constants

- **ARGOCD_CHART_VERSION**, **ARGOCD_CHART_REPO**  
  Used when installing the Argo CD Helm chart.

- **CILIUM_CHART_VERSION**, **CILIUM_CHART_REPO**  
  Used when installing the Cilium Helm chart.

- **NAMESPACES**  
  Array of namespaces created at the start: argocd, postgres, keycloak, backstage, monitoring, cert-manager, external-dns, pgadmin, gitea, k8sgpt.

- **CA_BUNDLE_NAMESPACES**  
  Namespaces that receive a `ca-bundle` ConfigMap (merged CA + Let's Encrypt). Subset of platform namespaces that need trust for TLS.

- **PG_APP_USERNAME**  
  Fixed value `"application"` for the PostgreSQL application user.

---

## Logging and Cleanup

**Logging**

- `log_info "msg"`  – stdout, prefix `[INFO]`
- `log_warn "msg"`  – stderr, prefix `[WARN]`
- `log_error "msg"` – stderr, prefix `[ERROR]`
- `log_step "msg"`   – blank line then `── msg ──` for phase headers

**Cleanup**

- `TEMP_FILES=()` and `trap cleanup EXIT` so that any file added via `make_temp_file` is removed on script exit (success or failure).
- `make_temp_file` runs `mktemp`, appends the path to `TEMP_FILES`, and prints it. Used in `install_cilium` for the ClusterMesh values file.

---

## Utility Functions

**generate_random_secret**

- Produces a 32-character alphanumeric string.
- Uses `openssl rand -base64 48`, strips non-alphanumeric characters, then takes the first 32. Avoids piping to `head` so that under `set -o pipefail` there is no SIGPIPE (see ADR-0016).

---

## Kubernetes Helper Functions

**filter_unchanged**

- Reads stdin and removes lines ending with ` unchanged$`.
- Used after `kubectl apply` so re-runs only show `created`/`configured`; `|| true` avoids non-zero exit when grep finds no matches.

**create_namespace(context, namespace)**

- `kubectl create namespace ... --dry-run=client -o yaml | kubectl apply ... -f -`, piped through `filter_unchanged`. Creates the namespace if missing; idempotent.

**create_secret(context, namespace, secret_name, ...)**

- First three arguments are context, namespace, secret name. Remaining arguments (e.g. `--from-literal=key=value`, `--type=...`) are passed through to `kubectl create secret generic`. Uses dry-run then apply so the secret is created or updated; output filtered with `filter_unchanged`.

**label_secret(context, namespace, secret_name, label)**

- `kubectl label secret ... "$label" --overwrite`. `--overwrite` makes re-runs idempotent.

**secret_exists(context, namespace, secret_name)**

- `kubectl get secret ...`; return code indicates existence (0) or not (non-zero). Output discarded.

**get_or_generate_secret(context, namespace, secret_name, [key])**

- Key defaults to `"password"`.
- If the secret does not exist: logs that it is generating, calls `generate_random_secret`, returns that value.
- If it exists: reads the secret key via `kubectl get secret ... -o jsonpath="{.data.$key}" | base64 -d` and returns it.
- Used so passwords and client secrets are stable across re-runs.

---

## Installation Functions

**generate_ca_cert_and_key(context)**

- **CA files:** If `.env/ca.crt` and `.env/ca.key` are missing, creates them with `openssl req -x509 -newkey rsa:4096 ...` (10-year, CN=ca.kuberise.local CA, O=KUBERISE, C=NL). Otherwise reuses them.
- **CA bundle:** Copies `scripts/letsencrypt.crt` into `.env`, concatenates CA cert and Let's Encrypt cert into `.env/ca-bundle.crt`, then removes the copied file.
- **cert-manager:** Creates (or updates) secret `ca-key-pair-external` in namespace `cert-manager` with the CA cert and key (TLS secret for the CA issuer).
- **ConfigMaps:** For each namespace in `CA_BUNDLE_NAMESPACES`, creates/updates a ConfigMap `ca-bundle` with key `ca.crt` from the bundle file.

**install_cilium(context, cluster_name)**

- Builds a `helm upgrade --install` command with:
  - `--kube-context`, `-n kube-system`, `--wait`
  - `-f values/defaults/platform/cilium/values.yaml`
  - `-f values/$cluster_name/platform/cilium/values.yaml`
- **Dynamic values:** Creates a temp file (via `make_temp_file`). Gets the current node InternalIP from the cluster and, if present, sets `k8sServiceHost` in that file.
- **ClusterMesh:** If `values/$cluster_name/platform/cilium/values.yaml` defines `clustermesh.config.clusters`, uses `yq` to read cluster names and for each cluster (including current) resolves the node IP (supports context names `$cluster` or `k3d-$cluster`). Writes a YAML fragment for `clustermesh.config.clusters` with name, port (32379), and optional `ips` into the temp file.
- Appends `-f <temp file>` and installs the `cilium` chart from `CILIUM_CHART_REPO` at `CILIUM_CHART_VERSION`.
- Restarts the Cilium DaemonSet and waits for rollout (`kubectl rollout restart ds/cilium`, then `rollout status` with 60s timeout).

**install_argocd(context, cluster_name, admin_password, domain)**

- Computes bcrypt hash of admin password: `htpasswd -nbBC 10 "" "$admin_password" | tr -d ':\n' | sed 's/$2y/$2a/'` (Argo CD expects `$2a`).
- Runs `helm upgrade --install` for the Argo CD chart with:
  - Context, namespace `argocd`, `--create-namespace`, `--wait`
  - Default and cluster-specific value files
  - `--set server.ingress.hostname=argocd.$domain`, `global.domain=argocd.$domain`, `configs.secret.argocdServerAdminPassword=<hash>`
  - Repo and version from constants. Chart name `argo-cd`, release name `argocd`. Output suppressed.

**deploy_app_of_apps(context, cluster_name, git_repo, git_revision, domain)**

- **AppProject:** Runs `helm template` on `./app-of-apps` with `global.clusterName=$cluster_name`, `--show-only templates/AppProject.yaml`, and applies the result to the `argocd` namespace.
- **Application:** Applies an Argo CD `Application` manifest (heredoc) for `app-of-apps-$cluster_name`:
  - Project name equals `$cluster_name`
  - Source: `repoURL`, `targetRevision`, `path: ./app-of-apps`, Helm `valueFiles: [values-$cluster_name.yaml]`
  - Helm parameters inject `global.spec.source.repoURL/targetRevision`, `global.spec.values.repoURL/targetRevision`, `global.clusterName`, `global.domain`
  - Destination: in-cluster, namespace `argocd`
  - Sync policy: automated with prune, selfHeal, allowEmpty; finalizer for cleanup.

**configure_oidc_auth(context, client_secret, domain, cluster_name)**

- Resolves the cluster name in kubeconfig for the given context.
- Adds a user `oidc-$cluster_name` with `kubectl config set-credentials` and an exec-based auth that runs `kubectl oidc-login get-token` with Keycloak issuer URL, client id `kubernetes`, and the given client secret.
- Adds a context `oidc-$cluster_name` using that cluster and user, namespace default. Logs that the user can switch with `kubectl config use-context oidc-$cluster_name`.

---

## Phase Functions

These are called only from `main` and group the lower-level helpers.

- **create_all_namespaces**  
  Loops over `NAMESPACES` and calls `create_namespace "$CONTEXT" "$ns"`.

- **configure_repo_access**  
  If `TOKEN` is set: creates secret `argocd-repo-platform` in `argocd` with name, username, password (token), url (repo URL), type=git; then labels it with `argocd.argoproj.io/secret-type=repository`.

- **create_database_secrets**  
  - PostgreSQL app: `get_or_generate_secret` for `database-app` in `postgres`, then `create_secret` with dbname, host, username, port, password (type `kubernetes.io/basic-auth`).
  - PostgreSQL superuser: same pattern for `database-superuser` with user `postgres`.
  - Gitea admin: secret `gitea-admin-secret` in `gitea`; password from `GITEA_ADMIN_PASSWORD` or `ADMIN_PASSWORD`.

- **create_application_secrets**  
  Creates secrets for: K8sGPT (if `OPENAI_API_KEY` set), Keycloak DB and admin and keycloak-access, Backstage DB, Grafana admin, optional Cloudflare for external-dns and cert-manager (if `CLOUDFLARE_API_TOKEN` set). Uses `PG_APP_USERNAME`, `PG_APP_PASSWORD`, `ADMIN_PASSWORD` where applicable.

- **configure_oauth2_clients**  
  For each of Kubernetes, Grafana, PGAdmin, OAuth2-Proxy, Argo CD: gets or generates a client secret in Keycloak (and for Grafana/PGAdmin/OAuth2-Proxy copies to the app namespace). For Kubernetes, calls `configure_oidc_auth`. For OAuth2-Proxy also gets or generates a cookie secret. For Argo CD, patches the existing `argocd-secret` with the base64-encoded OIDC client secret.

---

## Argument Parsing and Validation

**usage()**

- Prints usage text: required flags (`--context`, `--repo`), optional flags (`--cluster`, `--revision`, `--domain`, `--token`), environment variables (`ADMIN_PASSWORD`, `GITEA_ADMIN_PASSWORD`, `CLOUDFLARE_API_TOKEN`, `OPENAI_API_KEY`), and an example.

**parse_args()**

- Sets defaults: `CLUSTER_NAME=onprem`, `TARGET_REVISION=HEAD`, `DOMAIN=onprem.kuberise.dev`, `TOKEN=""`. Clears `CONTEXT` and `REPO_URL`.
- Loops over arguments with a `case` on `$1`; for each known flag consumes two arguments (flag and value) and sets the corresponding variable. `--help`/`-h` calls `usage` and exits 0. Unknown option: `log_error`, `usage`, exit 1.
- Sets `ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"`.

**validate()**

- Calls `check_required_tools`.
- Requires `CONTEXT` and `REPO_URL`; otherwise logs error, prints usage, exits 1.
- Requires directory `values/$CLUSTER_NAME`; on failure logs error and lists `values/` contents.
- Runs `kubectl cluster-info --context "$CONTEXT"`; if it fails, logs that the cluster is unreachable and exits.
- If `ADMIN_PASSWORD` is `admin`, logs a warning about the default password.

**check_required_tools()**

- For each of `kubectl`, `helm`, `htpasswd`, `openssl`, `cilium`, `yq`, runs `command -v "$tool"`. If any is missing, logs an error and exits 1.

---

## Commands and Tools Used

| Command / tool | Purpose |
|----------------|---------|
| **kubectl** | Create namespace/secret/configmap, label, get secret/node, apply YAML, patch secret, rollout restart/status, cluster-info, config set-credentials/set-context, config view |
| **helm** | upgrade --install (Cilium, Argo CD), template (app-of-apps AppProject) |
| **openssl** | rand -base64 (secrets), req -x509 (CA cert and key) |
| **htpasswd** | bcrypt hash for Argo CD admin password |
| **yq** | Read Cilium values (e.g. ClusterMesh cluster names) |
| **cilium** | Not invoked in script; presence checked for operator/CLI use |
| **base64** | Decode secret data from kubectl jsonpath output |
| **mktemp** | Via `make_temp_file` for temporary values file |
| **grep** | In `filter_unchanged` to drop "unchanged" lines |
| **sed** / **tr** | In bcrypt and secret formatting |

---

## File and Directory Assumptions

- **Repository root:** Script expects to be run from repo root so that:
  - `values/defaults/platform/...` and `values/$CLUSTER_NAME/platform/...` exist for Cilium and Argo CD.
  - `app-of-apps/` exists for Helm template and Application path.
  - `scripts/letsencrypt.crt` exists for the CA bundle.
- **Working directory:** `.env/` is created in the current working directory for CA cert, key, and bundle.
- **Kubeconfig:** Context and cluster names are read from default kubeconfig; OIDC user and context are written there.

---

## References

- [ADR-0016: Install Script Improvements](adr/0016-install-script-improvements.md) – Flags, idempotency, validation, phases.
- [ADR-0017: Bash Install Script over Custom CLI](adr/0017-bash-install-script-over-custom-cli.md) – Why the installer remains Bash.
- [Installation](public/1.getting-started/2.installation.md) – User-facing installation steps and examples.
