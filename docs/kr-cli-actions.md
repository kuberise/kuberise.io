# kr init and deploy - Essential vs Extra Actions

This document breaks down every action performed by `kr init` and `kr deploy`, categorizing each as **essential** (the platform cannot function without it) or **extra** (convenience or optional, can be removed or deferred).

## Essential Actions

These four actions form the minimum viable bootstrap. Without any of them, ArgoCD cannot manage the platform.

### 1. ArgoCD Installation (`install_argocd`)

**Command:** `kr init` (line 569)

Installs ArgoCD via Helm into the `argocd` namespace. This is the GitOps engine that manages everything else. Without it, there is no platform.

### 2. Repository Secrets (`configure_all_repo_access`, `configure_layer_repo_access`)

**Command:** `kr deploy` (lines 623, 639)

Creates Kubernetes secrets in the `argocd` namespace containing git credentials. ArgoCD uses these to clone the kuberise repo, client repo, and any layer-specific repos (e.g., kuberise-pro).

For public repos, no token is needed and the secret creation is skipped. For private repos, this is essential; ArgoCD would fail with "repository not accessible" errors.

### 3. ArgoCD AppProject (`create_app_project`)

**Command:** `kr deploy` (line 649)

Creates an ArgoCD `AppProject` named `kuberise` with wildcard permissions (all source repos, all namespaces, all resource types). Every app-of-apps Application references `project: kuberise`. Without this project, ArgoCD rejects all Applications.

### 4. App-of-Apps Applications (`create_layer_app_of_apps`)

**Command:** `kr deploy` (line 677)

Creates one ArgoCD Application per layer (e.g., `app-of-apps-platform`, `app-of-apps-pro`). Each Application uses three sources:
- Chart source from the kuberise repo (`app-of-apps/`)
- Layer values from the layer repo (via `$layer` ref)
- Enabler files from the client repo (via `$client` ref)

This is the trigger that causes ArgoCD to start deploying all enabled components.

---

## Extra Actions

These actions are not structurally required by ArgoCD but provide convenience, security material, or application-level secrets. Each can be removed or deferred depending on your setup.

### 1. Create Namespaces (`create_all_namespaces`)

**Command:** `kr init` (line 349)

**What it does:** Pre-creates 10 namespaces: argocd, postgres, keycloak, backstage, monitoring, cert-manager, external-dns, pgadmin, gitea, k8sgpt.

**Why it exists:** The extra actions below (secrets, CA material) need these namespaces to exist before they can create resources in them. ArgoCD itself can create namespaces during sync, but that happens later.

**If removed:** The subsequent secret-creation steps (CA, database, application, OAuth2) would fail because their target namespaces don't exist. If those are also removed, ArgoCD could create namespaces on its own during sync, but applications expecting pre-provisioned secrets would fail.

### 2. CA Certificate and Bundle (`generate_ca_cert_and_key`)

**Command:** `kr init` (line 356)

**What it does:**
- Generates a self-signed CA certificate and key (RSA 4096, 10-year validity), stored locally in `.env/ca.crt` and `.env/ca.key`
- Creates a CA bundle (self-signed CA + embedded Let's Encrypt ISRG Root X1)
- Creates TLS secret `ca-key-pair-external` in cert-manager namespace (used by cert-manager CA ClusterIssuer)
- Creates `ca-bundle` ConfigMap in 8 namespaces for apps that need to trust internal certificates

**Why it exists:** Development and internal clusters need a way to issue TLS certificates without public DNS. The CA bundle lets services trust both internal certs and public Let's Encrypt certs.

**If removed:** cert-manager has no CA issuer for internal certs. Applications that mount the `ca-bundle` ConfigMap would fail to start. Production clusters using only Let's Encrypt (with real DNS) could work without this, but you would also need to remove all `ca-bundle` ConfigMap references from Helm values.

### 3. Database Secrets (`create_database_secrets`)

**Command:** `kr init` (line 398)

**What it does:** Creates three secrets with random, idempotent passwords:
- `postgres/database-app` - PostgreSQL application user (username: `application`)
- `postgres/database-superuser` - PostgreSQL superuser
- `gitea/gitea-admin-secret` - Gitea admin credentials

**Why it exists:** CloudNativePG (the PostgreSQL operator) requires these secrets to exist before it creates the database cluster. It does not auto-generate credentials.

**If removed:** PostgreSQL fails to start. Gitea starts but without a pre-configured admin. Keycloak and Backstage (which receive copies of the PG password) also fail to connect.

### 4. Application Secrets (`create_application_secrets`)

**Command:** `kr init` (line 434)

**What it does:** Creates secrets for individual applications:
- `keycloak/pg-secret` - Keycloak's PostgreSQL credentials
- `keycloak/admin-secret` - Keycloak admin (admin / admin_password)
- `backstage/pg-secret` - Backstage's PostgreSQL password
- `monitoring/grafana-admin` - Grafana admin credentials
- `keycloak/keycloak-access` - Keycloak operator access
- `k8sgpt/openai-api` - OpenAI API key (only if `OPENAI_API_KEY` env var is set)
- `external-dns/cloudflare` and `cert-manager/cloudflare` - Cloudflare API token (only if `CLOUDFLARE_API_TOKEN` env var is set)

**Why it exists:** Applications expect their secrets to exist at startup. Without them, the Helm charts deploy but pods crash.

**If removed:** Each enabled application that depends on a secret fails to start. You can selectively skip secrets for applications you don't enable.

### 5. ArgoCD Admin Password (inside `install_argocd`)

**Command:** `kr init` (line 576)

**What it does:** Sets the ArgoCD admin password to a known value (default: `admin`) using a bcrypt hash passed via Helm `--set`.

**Why it exists:** Convenience for development. Operators can log in immediately with `admin/admin`.

**If removed:** ArgoCD generates a random admin password stored in the `argocd-initial-admin-secret` secret. Retrieve it with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
This is actually more secure for production environments.

### 6. Cilium Installation (`install_cilium`)

**Command:** `kr init` (line 589, only with `--cilium` flag)

**What it does:** Installs Cilium CNI into `kube-system` via Helm.

**Why it exists:** Some bare clusters (e.g., fresh kubeadm) ship without a CNI. Without one, pods cannot communicate.

**If removed:** Nothing breaks if the cluster already has a working CNI. This action is already optional, gated behind the `--cilium` flag.

### 7. OAuth2 Client Secrets and OIDC Configuration (`configure_oauth2_clients`)

**Command:** `kr init` (line 478)

**What it does:** Creates OAuth2 client secrets for five services that authenticate via Keycloak:
- **Kubernetes** - OIDC client secret + adds `oidc-{cluster}` user/context to kubeconfig
- **Grafana** - OAuth2 client secret (in keycloak and monitoring namespaces)
- **PGAdmin** - OAuth2 client secret (in keycloak and pgadmin namespaces)
- **OAuth2-Proxy** - OAuth2 client secret + cookie secret
- **ArgoCD** - OAuth2 client secret + patches `argocd-secret` with OIDC client secret

**Why it exists:** Enables centralized Single Sign-On (SSO) through Keycloak across the entire platform.

**If removed:** No SSO. All services fall back to local authentication using their own admin credentials (which still work). The `kubectl` OIDC context is not created. You can set this up manually later if needed.

---

## Summary

| Action | Category | If Removed |
|--------|----------|------------|
| ArgoCD installation | **Essential** | No platform |
| Repository secrets | **Essential** | ArgoCD can't clone private repos |
| AppProject | **Essential** | ArgoCD rejects all Applications |
| App-of-apps | **Essential** | Nothing gets deployed |
| Create namespaces | Extra | Secret creation steps fail |
| CA cert + bundle | Extra | No internal TLS, some apps crash |
| Database secrets | Extra | PostgreSQL and dependent apps fail |
| Application secrets | Extra | Affected apps fail to start |
| ArgoCD admin password | Extra | Random password generated (more secure) |
| Cilium | Extra | Already optional (--cilium flag) |
| OAuth2 + OIDC | Extra | No SSO, local auth only |

The essential actions are the structural minimum for ArgoCD to function. The extra actions solve the "secret bootstrapping" problem: applications need credentials at startup, but ArgoCD (which would normally manage everything) isn't running yet when these secrets must be created.
