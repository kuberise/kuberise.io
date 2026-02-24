# kr CLI Reference

This document describes the structure, flow, and implementation details of `scripts/kr`, the CLI tool that manages the full lifecycle of the kuberise.io platform on Kubernetes clusters. See [Installation](public/1.getting-started/2.installation.md) for user-facing usage.

## Overview

`kr` is a Bash CLI that orchestrates the full platform lifecycle:

- **`kr up`** - The primary command: bootstraps clusters that need it, then deploys all layers (init-if-needed + deploy)
- **`kr init`** - Bootstraps a bare cluster: creates namespaces, secrets, CA material, installs Argo CD
- **`kr deploy`** - Deploys all layers to already-bootstrapped clusters via Argo CD Applications
- **`kr uninstall`** / **`kr down`** - Tears down the platform from a cluster
- **`kr version`** - Prints the current kr version

After `kr` finishes, Argo CD owns all further deployment. The tool is **idempotent**: safe to run multiple times. It supports **multi-cluster** and **multi-layer** deployments driven by `kuberise.yaml`. Design rationale is recorded in [ADR-0016](adr/0016-install-script-improvements.md) and [ADR-0017](adr/0017-bash-install-script-over-custom-cli.md).

## Prerequisites

**Required tools vary by command:**

| Command | Required tools |
|---------|---------------|
| `kr init` | `kubectl`, `helm`, `htpasswd`, `openssl` |
| `kr deploy` | `kubectl`, `helm`, `yq`, `git` |
| `kr up` | `kubectl`, `helm`, `htpasswd`, `openssl`, `yq`, `git` |
| `kr uninstall` | `kubectl`, `helm` |

Each command validates its required tools at startup and exits if any are missing.

**Configuration:** Most commands read `kuberise.yaml` from the current directory (or a path specified with `--config`). If `--repo` is provided and the config file is not found locally, `kr deploy` and `kr up` attempt to fetch it from the remote repo via shallow git clone. The client repo URL is resolved from `--repo` flag, then `client.repoURL` in `kuberise.yaml`, or an error if neither is set.

**Installation:**

```bash
curl -sSL https://kuberise.io/install | sh
# or with a specific version
curl -sSL https://kuberise.io/install | KR_VERSION=0.4.0 sh
```

## Script Structure

The script (2,227 lines) is organized into sections with comment headers:

| Section | Lines (approx.) | Purpose |
|--------|------------------|---------|
| Shebang and version | 1-5 | `#!/bin/bash`, `set -euo pipefail`, `KR_VERSION` |
| Constants | 7-102 | Chart versions, repo URLs, namespace lists, Helm release lists |
| Embedded resources | 104-139 | ISRG Root X1 (Let's Encrypt) certificate |
| Logging | 141-156 | `log_info`, `log_warn`, `log_error`, `log_step` with color support |
| Cleanup | 158-182 | Temp file/directory tracking and `EXIT` trap |
| Utility functions | 184-246 | `inject_token_into_url`, `fetch_kuberise_yaml`, `generate_random_secret` |
| Kubernetes helpers | 248-344 | `apply_manifest`, namespace/secret helpers, `get_or_generate_secret` |
| Init functions | 346-600 | CA, Cilium, Argo CD, secrets, OAuth2 |
| Deploy functions | 602-757 | Repo access, AppProject, per-layer app-of-apps |
| Uninstall functions | 759-1120 | Application removal, namespace cleanup, kubeconfig cleanup |
| Prerequisite checks | 1122-1172 | Per-command tool validation, cluster reachability, Argo CD detection |
| Usage and argument parsing | 1174-1553 | Per-command usage, parsing, validation, kuberise.yaml parsing |
| Subcommand implementations | 1555-2209 | `cmd_version`, `cmd_init`, `cmd_deploy`, `cmd_up`, `cmd_uninstall` |
| Main dispatch | 2211-2227 | Command router via `case` statement |

## Commands

### `kr up` (Primary Command)

Initialize (if needed) and deploy all clusters defined in `kuberise.yaml`. For each accessible cluster, checks whether Argo CD is installed; if not, runs init first, then deploys all layers. Already-initialized clusters skip straight to deploy.

The client repo URL is resolved in this order: `--repo` flag > `client.repoURL` in `kuberise.yaml` > error.

**Optional flags:**
- `--repo REPO_URL` - Git repository URL for the client repo (overrides `client.repoURL` in config)
- `--admin-password PWD` - Admin password for init (default: `admin`, warns if default)
- `--cilium` - Install Cilium CNI on clusters that need init
- `--revision REV` - Client repo branch, tag, or commit SHA (default: `HEAD`, overrides `client.targetRevision`)
- `--token TOKEN` - Git token for private repositories (fallback for all repos)
- `--cluster NAME` - Target only this cluster (default: all clusters)
- `--layer NAME` - Deploy only this layer (default: all layers)
- `--config PATH` - Path to `kuberise.yaml` (default: `./kuberise.yaml`)
- `--retry-interval SECS` - Seconds between retries for inaccessible clusters (default: 30)
- `--retry-timeout SECS` - Max seconds to wait for inaccessible clusters (default: 300)
- `--dry-run` - Show what would be applied without making changes

### `kr init`

Bootstrap Kubernetes clusters with kuberise platform prerequisites. Supports two modes: **kuberise.yaml mode** (reads cluster config from file) and **legacy single-cluster mode** (requires `--context` and `--domain` flags).

**Optional flags:**
- `--admin-password PWD` - Admin password (default: `admin`)
- `--cilium` - Also install Cilium CNI
- `--cluster NAME` - Init only this cluster (when using kuberise.yaml)
- `--config PATH` - Path to `kuberise.yaml` (default: `./kuberise.yaml`)
- `--context CONTEXT` - Kubernetes context name (legacy mode)
- `--domain DOMAIN` - Base domain for services (legacy mode)

**Environment variables:** `ADMIN_PASSWORD`, `GITEA_ADMIN_PASSWORD`, `CLOUDFLARE_API_TOKEN`, `OPENAI_API_KEY`.

### `kr deploy`

Deploy all clusters and layers defined in `kuberise.yaml`. Requires that clusters are already bootstrapped (Argo CD must be installed). Deploys to all clusters in parallel, with retry for inaccessible clusters.

The client repo URL is resolved in this order: `--repo` flag > `client.repoURL` in `kuberise.yaml` > error.

**Optional flags:**
- `--repo REPO_URL` - Git repository URL for the client repo (overrides `client.repoURL` in config)
- `--revision REV` - Client repo branch, tag, or commit SHA (default: `HEAD`, overrides `client.targetRevision`)
- `--token TOKEN` - Git token for private repositories (fallback for all repos)
- `--cluster NAME` - Deploy only this cluster
- `--layer NAME` - Deploy only this layer
- `--config PATH` - Path to `kuberise.yaml` (default: `./kuberise.yaml`)
- `--retry-interval SECS` - Seconds between retries (default: 30)
- `--retry-timeout SECS` - Max seconds to wait (default: 300)
- `--dry-run` - Show what would be applied without making changes

### `kr uninstall` / `kr down`

Tear down the kuberise platform from a cluster. Removes all app-of-apps layers, Argo CD, kuberise-managed namespaces, and kubeconfig entries. Cilium CNI is intentionally **not** removed since the cluster needs it for networking.

**Required flags:**
- `--context CONTEXT` - Kubernetes context name
- `--cluster NAME` - Cluster name (must match the name used during init)

**Optional flags:**
- `--yes`, `-y` - Skip interactive confirmation prompt

---

## Execution Flows

### `kr up` Flow

1. **Parse and validate** - Parse arguments, check all required tools (init + deploy), locate or fetch `kuberise.yaml`.
2. **Parse kuberise.yaml** - Extract cluster names, contexts, domains, destinations, and layers. Resolve client repo URL and revision from CLI flags or `client:` section.
3. **Check accessibility** - For each target cluster, verify kubectl connectivity.
4. **Process accessible clusters in parallel** - For each cluster (forked background processes):
   a. Check if Argo CD is installed (`helm status argocd`).
   b. If not installed, run `init_cluster()` to bootstrap.
   c. Run deploy logic: configure repo access, create AppProject, create per-layer app-of-apps Applications.
5. **Retry inaccessible clusters** - Poll with configurable interval/timeout, then process when they become accessible.
6. **Report results** - Summarize which clusters were initialized and deployed.

### `kr init` Flow (per cluster)

1. **Create namespaces** - Create each namespace in the `NAMESPACES` array.
2. **Generate CA certificates** - Create or reuse self-signed CA, build CA bundle with Let's Encrypt cert.
3. **Create database secrets** - PostgreSQL app/superuser passwords, Gitea admin secret.
4. **Create application secrets** - Secrets for Keycloak, Grafana, Backstage, K8sGPT, Cloudflare.
5. **Install Cilium** (optional) - Helm install with default and cluster-specific values.
6. **Install Argo CD** - Helm install with bcrypt-hashed admin password and domain config.
7. **Configure OAuth2 clients** - Client secrets for Kubernetes, Grafana, PGAdmin, OAuth2-Proxy, Argo CD; configure OIDC in kubeconfig.

### `kr deploy` Flow (per cluster)

1. **Verify Argo CD installed** - Check Helm release exists in argocd namespace.
2. **Configure repo access** - Create Argo CD repository secrets for kuberise repo, client repo, and each layer's repo.
3. **Create AppProject** - Create Argo CD AppProject with wildcard permissions via `helm template`.
4. **Create per-layer app-of-apps** - For each layer, create an Argo CD Application manifest using the multi-source pattern (chart source + layer values source + client config source).

### `kr uninstall` Flow

1. **Collect namespaces** - Discover all kuberise-managed namespaces (hardcoded list + discovered from Argo CD applications).
2. **Confirm** - Interactive confirmation prompt (unless `--yes`).
3. **Delete app-of-apps** - Remove all app-of-apps Application resources.
4. **Delete remaining applications** - Wait for Argo CD application deletion with timeout.
5. **Uninstall Helm releases** - Remove Argo CD and any kube-system Helm releases.
6. **Clean up webhooks** - Remove orphaned validating/mutating webhook configurations.
7. **Clear stuck resources** - Remove finalizers on resources stuck in terminating state.
8. **Clear stuck PVCs and PVs** - Handle orphaned persistent volumes.
9. **Delete namespaces** - Wait for namespace termination with timeout, force cleanup if needed.
10. **Clean up kubeconfig** - Remove OIDC user and context entries.

---

## Constants

- **KR_VERSION** - Current version of the kr CLI (0.4.0).

- **ARGOCD_CHART_VERSION**, **ARGOCD_CHART_REPO** - Used when installing the Argo CD Helm chart.

- **CILIUM_CHART_VERSION**, **CILIUM_CHART_REPO** - Used when installing the Cilium Helm chart.

- **NAMESPACES** - Array of namespaces created during init: argocd, postgres, keycloak, backstage, monitoring, cert-manager, external-dns, pgadmin, gitea, k8sgpt.

- **CA_BUNDLE_NAMESPACES** - Namespaces that receive a `ca-bundle` ConfigMap (merged CA + Let's Encrypt). Subset of platform namespaces that need trust for TLS.

- **KUBERISE_NAMESPACES** - Comprehensive list of all namespaces kuberise may create (via init or Argo CD apps). Used during uninstall to discover what to clean up. Organized by category: Platform Core, Data Services, Network Services, Security and Auth, Monitoring, AI Tools, CI/CD, Multi-cluster, Example applications.

- **PG_APP_USERNAME** - Fixed value `"application"` for the PostgreSQL application user.

- **KUBE_SYSTEM_HELM_RELEASES** - Helm releases installed in kube-system by kr init (currently empty; Cilium is intentionally not uninstalled).

- **LETSENCRYPT_CRT** - ISRG Root X1 (Let's Encrypt) certificate, embedded directly in the script. Used for building the CA bundle.

---

## Logging and Cleanup

**Logging**

- `log_info "msg"` - stdout, prefix `[INFO]`, cyan
- `log_warn "msg"` - stderr, prefix `[WARN]`, yellow
- `log_error "msg"` - stderr, prefix `[ERROR]`, red
- `log_step "msg"` - blank line then `── msg ──` for phase headers, bold cyan

Colors are automatically disabled when output is not a TTY or when the `NO_COLOR` environment variable is set.

**Cleanup**

- `TEMP_FILES=()` and `TEMP_DIRS=()` track temporary resources. `trap cleanup EXIT` removes them on script exit (success or failure).
- `make_temp_file` runs `mktemp`, appends the path to `TEMP_FILES`, and prints it.
- Temporary directories (used by `fetch_kuberise_yaml` for shallow clones) are tracked in `TEMP_DIRS`.

---

## Utility Functions

**inject_token_into_url(url, token)**

- Converts `https://github.com/org/repo.git` to `https://x:TOKEN@github.com/org/repo.git` for authenticated cloning.

**fetch_kuberise_yaml(repo_url, revision, token, config_path)**

- Fetches a config file (default: `kuberise.yaml`) from a remote git repo when it is not found locally.
- The `config_path` parameter (default: `kuberise.yaml`) allows fetching files at custom paths inside the repo.
- Uses shallow clone (`--depth 1`) with sparse checkout to minimize bandwidth.
- Supports authenticated repos via token injection.
- Temporary clone directory is tracked for cleanup.

**generate_random_secret**

- Produces a 32-character alphanumeric string.
- Uses `openssl rand -base64 48`, strips non-alphanumeric characters via parameter expansion, then takes the first 32. Avoids piping to `head` so that under `set -o pipefail` there is no SIGPIPE (see ADR-0016).

---

## Kubernetes Helper Functions

**apply_manifest(context, namespace, manifest)**

- Applies a Kubernetes manifest via `kubectl apply`. In dry-run mode (`KR_DRY_RUN=true`), prints the manifest instead of applying it.

**create_namespace(context, namespace)**

- `kubectl create namespace ... --dry-run=client -o yaml | kubectl apply ... -f -`. Creates the namespace if missing; idempotent.

**create_secret(context, namespace, secret_name, ...)**

- First three arguments are context, namespace, secret name. Remaining arguments (e.g. `--from-literal=key=value`, `--type=...`) are passed through to `kubectl create secret generic`. Uses dry-run then apply so the secret is created or updated.

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

## Init Functions

**generate_ca_cert_and_key(context)**

- **CA files:** If `.env/ca.crt` and `.env/ca.key` are missing, creates them with `openssl req -x509 -newkey rsa:4096 ...` (10-year, CN=ca.kuberise.local CA, O=KUBERISE, C=NL). Otherwise reuses them.
- **CA bundle:** Uses the embedded Let's Encrypt certificate, concatenates CA cert and Let's Encrypt cert into `.env/ca-bundle.crt`.
- **cert-manager:** Creates (or updates) secret `ca-key-pair-external` in namespace `cert-manager` with the CA cert and key (TLS secret for the CA issuer).
- **ConfigMaps:** For each namespace in `CA_BUNDLE_NAMESPACES`, creates/updates a ConfigMap `ca-bundle` with key `ca.crt` from the bundle file.

**install_cilium(context)**

- Builds a `helm upgrade --install` command with `--kube-context`, `-n kube-system`, `--wait`, and default values.
- Installs the `cilium` chart from `CILIUM_CHART_REPO` at `CILIUM_CHART_VERSION`.

**install_argocd(context, admin_password, domain)**

- Computes bcrypt hash of admin password: `htpasswd -nbBC 10 "" "$admin_password" | tr -d ':\n' | sed 's/$2y/$2a/'` (Argo CD expects `$2a`).
- Runs `helm upgrade --install` for the Argo CD chart with:
  - Context, namespace `argocd`, `--create-namespace`, `--wait`
  - Default and cluster-specific value files
  - `--set server.ingress.hostname=argocd.$domain`, `global.domain=argocd.$domain`, `configs.secret.argocdServerAdminPassword=<hash>`
  - Repo and version from constants. Chart name `argo-cd`, release name `argocd`. Output suppressed.

**configure_oidc_auth(context, client_secret, domain, cluster_name)**

- Resolves the cluster name in kubeconfig for the given context.
- Adds a user `oidc-$cluster_name` with `kubectl config set-credentials` and an exec-based auth that runs `kubectl oidc-login get-token` with Keycloak issuer URL, client id `kubernetes`, and the given client secret.
- Adds a context `oidc-$cluster_name` using that cluster and user, namespace default.

---

## Deploy Functions

**configure_repo_secret(context, secret_name, repo_url, token)**

- Creates an Argo CD repository secret in the `argocd` namespace with the given name, URL, and token. Labels it with `argocd.argoproj.io/secret-type=repository`.

**configure_all_repo_access(context, ...)**

- Configures repo access for the kuberise repo, the client repo, and each layer's repo. Handles token injection for private repos.

**configure_layer_repo_access(context, layer_name, layer_repo, layer_token)**

- Creates layer-specific Argo CD repository secrets with appropriate naming.

**create_app_project(context, cluster_name, destination)**

- Creates an Argo CD AppProject via `helm template` on the `./app-of-apps` chart with `global.clusterName=$cluster_name`, applied to the `argocd` namespace.

**create_layer_app_of_apps(context, cluster_name, layer_name, ...)**

- Creates a per-layer Argo CD Application manifest using the multi-source pattern:
  1. **Chart source** - The `app-of-apps` chart from the kuberise repo
  2. **Layer values source** - `values-base.yaml` from the layer's repo
  3. **Client config source** - Enabler file (`values-{clusterName}-{layerName}.yaml`) from the client repo
- Sync policy: automated with prune, selfHeal, allowEmpty; finalizer for cleanup.

---

## Uninstall Functions

**collect_uninstall_namespaces(context)**

- Discovers all kuberise-managed namespaces by combining the hardcoded `KUBERISE_NAMESPACES` list with namespaces discovered from Argo CD application destinations.

**remove_app_of_apps(context, cluster_name)**

- Deletes all app-of-apps Application resources and the AppProject.

**delete_all_applications(context)**

- Waits for all Argo CD applications to be deleted, with configurable timeout.

**clear_stuck_managed_resources(context)**

- Clears finalizers on resources stuck in a terminating state after application deletion.

**clear_stuck_pvcs_and_pvs(context)**

- Handles orphaned PersistentVolumeClaims and PersistentVolumes that remain after namespace deletion.

**cleanup_stuck_namespaces(context)**

- Waits for namespace termination with timeout, then force-cleans namespaces still stuck by clearing finalizers.

**cleanup_kubeconfig(context, cluster_name)**

- Removes OIDC user (`oidc-$cluster_name`) and context entries from kubeconfig.

---

## Phase Functions

These group the lower-level helpers and are called from the subcommand implementations.

- **create_all_namespaces** - Loops over `NAMESPACES` and calls `create_namespace "$context" "$ns"`.

- **create_database_secrets** - PostgreSQL app: `get_or_generate_secret` for `database-app` in `postgres`, then `create_secret` with dbname, host, username, port, password (type `kubernetes.io/basic-auth`). PostgreSQL superuser: same pattern for `database-superuser` with user `postgres`. Gitea admin: secret `gitea-admin-secret` in `gitea`; password from `GITEA_ADMIN_PASSWORD` or `ADMIN_PASSWORD`.

- **create_application_secrets** - Creates secrets for: K8sGPT (if `OPENAI_API_KEY` set), Keycloak DB and admin and keycloak-access, Backstage DB, Grafana admin, optional Cloudflare for external-dns and cert-manager (if `CLOUDFLARE_API_TOKEN` set). Uses `PG_APP_USERNAME`, `PG_APP_PASSWORD`, `ADMIN_PASSWORD` where applicable.

- **configure_oauth2_clients** - For each of Kubernetes, Grafana, PGAdmin, OAuth2-Proxy, Argo CD: gets or generates a client secret in Keycloak (and for Grafana/PGAdmin/OAuth2-Proxy copies to the app namespace). For Kubernetes, calls `configure_oidc_auth`. For OAuth2-Proxy also gets or generates a cookie secret. For Argo CD, patches the existing `argocd-secret` with the base64-encoded OIDC client secret.

---

## kuberise.yaml Format

The `kuberise.yaml` file is the declarative configuration source for multi-cluster, multi-layer deployments:

```yaml
client:
  repoURL: https://github.com/org/client-webshop.git
  targetRevision: main  # optional, default: HEAD

kuberise:
  repoURL: https://github.com/kuberise/kuberise.io.git
  targetRevision: 0.4.0

clusters:
  mgmt:
    context: k3d-mgmt
    domain: mgmt.webshop.kuberise.dev
    destination: https://kubernetes.default.svc  # optional
    layers:
      - name: platform
        repoURL: kuberise
        targetRevision: main
      - name: pro
        repoURL: https://github.com/myorg/kuberise-pro.git
        token: GIT_TOKEN_ENV_VAR_NAME  # optional
      - name: webshop  # defaults to client repo
  dev:
    context: k3d-dev
    domain: dev.webshop.kuberise.dev
    layers:
      - name: platform
        repoURL: kuberise
      - name: webshop
```

**`client:` section** (optional): Declares the client repo URL and revision. When present, `--repo` becomes optional for `kr up` and `kr deploy`. The `--repo` flag takes priority over `client.repoURL`; the `--revision` flag (when explicitly provided) takes priority over `client.targetRevision`. If neither `--repo` nor `client.repoURL` is set, the command errors with a helpful message.

**Parsing:** `parse_kuberise_yaml()` uses `yq` to extract cluster names, and `get_cluster_config()` / `get_layer_config()` extract per-cluster and per-layer settings. After parsing, `resolve_client_repo()` merges CLI flags with the `client:` section to set `DEPLOY_REPO` and `DEPLOY_REVISION`. Layer `repoURL: kuberise` resolves to the OSS repo; empty `repoURL` defaults to the client repo.

**Enabler files:** Use the naming convention `values-{clusterName}-{layerName}.yaml` and live in the client repo's `app-of-apps/` directory.

---

## Argument Parsing and Validation

Each subcommand has its own `usage_*()`, `parse_*_args()`, and `validate_*()` functions.

**`parse_init_args`** - Sets defaults: `INIT_CLUSTER=""`, `INIT_CILIUM=false`, `INIT_CONFIG=kuberise.yaml`. Loops over arguments with a `case` on `$1`. Sets `INIT_ADMIN_PASSWORD` from flag or `ADMIN_PASSWORD` env var (default: `admin`).

**`validate_init`** (legacy mode) - Calls `check_required_tools_init`. Requires `INIT_CONTEXT` and `INIT_DOMAIN`. Verifies cluster is reachable.

**`parse_deploy_args`** - Sets defaults: `DEPLOY_REVISION=HEAD`, `DEPLOY_CONFIG=kuberise.yaml`, `DEPLOY_DRY_RUN=false`, `DEPLOY_RETRY_INTERVAL=30`, `DEPLOY_RETRY_TIMEOUT=300`. Also tracks `DEPLOY_CONFIG_EXPLICIT` and `DEPLOY_REVISION_EXPLICIT` booleans to distinguish user-provided values from defaults.

**`validate_deploy`** - Calls `check_required_tools_deploy`. If `--repo` is provided and config is not found locally, fetches it from the remote repo. If `--repo` is not provided, the config file must exist locally.

**`parse_up_args`** - Combines init and deploy flags. Sets defaults for both init (admin password, cilium) and deploy (repo, revision, token, retry) parameters. Tracks `UP_CONFIG_EXPLICIT` and `UP_REVISION_EXPLICIT`.

**`validate_up`** - Checks all tools needed for both init and deploy: `kubectl`, `helm`, `htpasswd`, `openssl`, `yq`, `git`. Same config resolution logic as `validate_deploy`: fetches remotely only when `--repo` is provided.

**`resolve_client_repo(config_file, cli_repo, cli_revision, revision_explicit)`** - Called after `parse_kuberise_yaml` in both `cmd_deploy` and `cmd_up`. Resolves the client repo URL and revision by merging CLI flags with the `client:` section in `kuberise.yaml`. Sets `DEPLOY_REPO` and `DEPLOY_REVISION` as globals. Priority: `--repo` > `client.repoURL` > error; explicit `--revision` > `client.targetRevision` > `"HEAD"`.

**`parse_uninstall_args`** - Requires `--context` and `--cluster`. Optional `--yes`/`-y` to skip confirmation.

---

## Commands and Tools Used

| Command / tool | Purpose |
|----------------|---------|
| **kubectl** | Create namespace/secret/configmap, label, get secret/node/application, apply/delete YAML, patch secret, cluster-info, config set-credentials/set-context/delete-context/delete-user, config view |
| **helm** | upgrade --install (Cilium, Argo CD), template (AppProject), status (Argo CD detection), uninstall |
| **openssl** | rand -base64 (secrets), req -x509 (CA cert and key) |
| **htpasswd** | bcrypt hash for Argo CD admin password |
| **yq** | Parse kuberise.yaml (cluster names, contexts, domains, layers) |
| **git** | Shallow clone for remote kuberise.yaml fetch |
| **base64** | Decode secret data from kubectl jsonpath output |
| **mktemp** | Via `make_temp_file` for temporary values files |
| **sed** / **tr** | In bcrypt hash formatting, token URL injection |

---

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `ADMIN_PASSWORD` | Admin password (alternative to `--admin-password`) |
| `GITEA_ADMIN_PASSWORD` | Gitea admin password (default: value of admin password) |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for ExternalDNS and cert-manager |
| `OPENAI_API_KEY` | OpenAI API key for K8sGPT |
| `NO_COLOR` | Disables colored log output |
| Per-layer token vars | Git tokens for private layer repos, referenced by name in kuberise.yaml `token:` field |

---

## File and Directory Assumptions

- **Client repo root:** `kr up` and `kr deploy` expect to be run from the client repo root so that `kuberise.yaml` and `app-of-apps/` directories resolve correctly.
- **Platform repo:** The kuberise.io repo must contain `values/defaults/platform/...` and `app-of-apps/` for Argo CD to consume.
- **Working directory:** `.env/` is created in the current working directory for CA cert, key, and bundle.
- **Kubeconfig:** Context and cluster names are read from default kubeconfig; OIDC user and context entries are written/removed there.

---

## References

- [ADR-0016: Install Script Improvements](adr/0016-install-script-improvements.md) - Flags, idempotency, validation, phases.
- [ADR-0017: Bash Install Script over Custom CLI](adr/0017-bash-install-script-over-custom-cli.md) - Why the installer remains Bash.
- [Installation](public/1.getting-started/2.installation.md) - User-facing installation steps and examples.
