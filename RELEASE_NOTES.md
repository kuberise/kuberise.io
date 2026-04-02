# Release Notes

## [0.5.0] - 2 April 2026

### Gateway API, Unlimited Sync Retries, and 20+ Chart Upgrades

This release adds Gateway API support with a dedicated config chart, switches ArgoCD sync retries to unlimited with exponential backoff to eliminate sync-wave deadlocks, splits Cilium into operator and config charts, and upgrades 20+ external Helm charts to their latest versions.

### Added
- **Gateway API support** - new `gateway-api-crds` app (kustomize, from upstream `kubernetes-sigs/gateway-api`) installs Gateway API CRDs, and a new `gateway-config` chart provisions Gateway resources, HTTP-to-HTTPS redirect, per-service HTTPRoutes, ReferenceGrant, and an optional DNS target service.
- **`cilium-config` chart** - new config chart for Cilium CR instances (L2AnnouncementPolicy, LoadBalancerIPPool), following the operator + config chart pattern used by cert-manager and keycloak.
- **cert-manager SSA webhook fix** - added `ignoreDifferences` with `RespectIgnoreDifferences=true` for `caBundle` on ValidatingWebhookConfiguration and MutatingWebhookConfiguration to resolve server-side apply conflicts. Includes a troubleshooting guide in `docs/public/`.

### Changed
- **Unlimited sync retries** (ADR-0007 update) - sync retry policy changed from `limit: 5` to `limit: -1` (unlimited) with exponential backoff. Bounded retries caused earlier sync waves to exhaust their retry budget before dependencies were ready, permanently blocking all later waves.
- **`ignoreMissingValueFiles` disabled** - commented out to enforce that all expected value files exist. This catches misconfiguration early rather than silently skipping missing files.
- **`internal-dns` switched to upstream chart** - now uses the `kubernetes-sigs.github.io/external-dns/` Helm repo instead of the Bitnami OCI chart.
- **`kr` CLI improvements** - fixed ArgoCD install param escaping (`server.insecure`), `--cluster` targeting now includes child clusters via `parent:` in `kuberise.yaml`, added parent reference validation, and `kr up` now always runs idempotent init (upgrade if already installed).
- **Cilium updated to 1.20.0-pre.1** - updated install params to use `ipam.mode=kubernetes`, added `ignoreDifferences` for Secret data to prevent drift detection on auto-generated secrets.
- **20+ chart version bumps** - argocd-image-updater 1.1.4, rancher 2.14.0, vcluster 0.34.0, cloudnative-pg 0.28.0, pgadmin4 1.62.0, redis 25.3.9, ingress-nginx 4.15.1, aws-lb-controller 3.1.0, keycloakx 7.1.9, external-secrets 2.2.0, oauth2-proxy 10.4.2, cert-manager v1.21.0-alpha.0, kyverno 3.7.1, vault-secrets-operator 1.3.0, trivy-operator 0.32.1, neuvector 2.8.12, kube-prometheus-stack 82.16.1, opencost 2.5.12, ollama 1.54.0, k8sgpt 0.2.27.

### Removed
- **`external-dns` duplicate entry** - consolidated `external-dns` and `external-dns-sigs` into a single `external-dns` app using the upstream kubernetes-sigs chart.

## [0.4.0] - 24 February 2026

### Declarative Multi-Cluster Deployment with `kr up`

This release introduces `kuberise.yaml`, a declarative cluster manifest that describes the full desired state of all clusters managed by a client repo. The new `kr up` command reads this file and handles the complete lifecycle: bootstrapping clusters that need initialization and deploying all layers to clusters that are already running. Clusters are processed in parallel with automatic retry for clusters that are not yet accessible (e.g., clusters being provisioned by CAPI).

### Added
- **`kr up` command** - the primary command for managing clusters. Reads `kuberise.yaml`, detects whether each cluster needs initialization (via `helm status argocd`), runs `kr init` for new clusters, then deploys all layers. Accessible clusters are processed in parallel; inaccessible clusters are retried with configurable interval and timeout (`--retry-interval`, `--retry-timeout`).
- **`kr down` command** - alias for `kr uninstall`, providing an intuitive `up`/`down` pair.
- **`kuberise.yaml` support** - declarative cluster manifest at the root of each client repo. Declares `client.repoURL`, `kuberise.repoURL`/`targetRevision`, and a `clusters:` map where each cluster defines its `context`, `domain`, and `layers`. Each layer specifies a `name`, optional `repoURL` (`kuberise` for the OSS repo, omit for the client repo, or an explicit URL), optional `targetRevision`, and optional `token` (environment variable name for authentication).
- **`--dry-run` flag** for `kr deploy` and `kr up` - preview all Kubernetes manifests that would be applied without making changes.
- **`--cluster` filter** for `kr deploy` and `kr up` - target a single cluster instead of all clusters defined in `kuberise.yaml`.
- **`--layer` filter** for `kr up` - deploy only a specific layer within each cluster.
- **Remote config fetching** - `kr up --repo <URL>` can fetch `kuberise.yaml` from a remote git repo via shallow clone when not running from the client repo directory.
- **Per-layer token resolution** - each layer in `kuberise.yaml` can specify a `token:` field with the name of an environment variable, enabling secure authentication to private repos without storing credentials in git.
- **ADR-0023** documenting the single AppProject-per-cluster pattern (supersedes ADR-0013).
- **ADR-0024** documenting the rationale for per-repository authentication.

### Changed
- **`kr deploy` now reads `kuberise.yaml`** - resolves clusters, layers, and repos from the config file instead of requiring all values as CLI flags. CLI flags (`--repo`, `--revision`, `--token`) override the config file values.
- **Parallel multi-cluster deployment** - both `kr deploy` and `kr up` process accessible clusters in parallel using background processes with PID tracking and error collection. A single cluster deploys inline (no background process overhead).
- **AppProject management** - the ArgoCD AppProject is now created imperatively via `kubectl apply` in `kr deploy` instead of via Helm template, breaking the circular dependency during uninstall (ADR-0023).
- **Enhanced uninstall** - `kr uninstall` (and `kr down`) now clears finalizers on stuck resources, handles PVCs/PVs in Terminating state, removes orphaned ValidatingWebhookConfigurations and MutatingWebhookConfigurations, and cleans up OIDC context/user entries from kubeconfig.
- **Enabler file naming** - enabler files now use `values-{clusterName}-{layerName}.yaml` convention for multi-cluster support (e.g., `values-dev-platform.yaml`).

## [0.3.0] - 18 February 2026

### Standalone `kr` CLI Tool

This release introduces `kr`, a standalone CLI tool that replaces `install.sh` with a cleaner separation of concerns: cluster bootstrap (`kr init`) vs layer deployment (`kr deploy`). The tool is self-contained (no repo clone needed) and supports deploying multiple layers independently.

### Added
- **`kr` CLI tool** (`scripts/kr`) - standalone bash script with subcommands: `version`, `init`, `deploy`, `uninstall`.
- **`kr init`** - bootstraps a cluster with namespaces, secrets, CA certificates, and ArgoCD. Optionally installs Cilium with `--cilium`. No values files or repo clone required.
- **`kr deploy`** - deploys an app-of-apps layer. The `--name` flag is a short layer identifier (default: `shared`) that controls the Application name (`app-of-apps-{name}`), enabler file (`values-{name}.yaml`), and repo secret (`argocd-repo-{name}`). Can be called multiple times with different `--name` values (e.g., `--name webshop`).
- **`kr uninstall`** - full teardown (migrated from `uninstall.sh`), including stuck resource cleanup and kubeconfig removal.
- **Inline AppProject** - generated directly via kubectl apply instead of `helm template`, removing the dependency on a local repo checkout during deploy.
- **Embedded Let's Encrypt certificate** - the ISRG Root X1 certificate is embedded in the script instead of read from a file.
- **`scripts/install-kr.sh`** - curl-based installer for downloading `kr` from GitHub releases.

### Changed
- **ArgoCD bootstrap uses `--set` flags** - installs with admin password, insecure mode, and ClusterIP. Full configuration (ingress, OIDC, health checks, resource customizations) is applied via GitOps after `kr deploy`.
- **Cilium bootstrap installs the CNI** - advanced configuration (ClusterMesh, etc.) is applied via GitOps after `kr deploy`.
- **Repo access secrets include layer name** - secret names use the `--name` identifier (e.g., `argocd-repo-clientName`) to prevent conflicts when deploying multiple layers.

### Removed
- **`scripts/install.sh`** - replaced by `kr init` + `kr deploy`.
- **`scripts/uninstall.sh`** - replaced by `kr uninstall`.

## [0.2.0] - 14 February 2026

### Improved Install UX: Named Flags, Clearer Prerequisites, and Docs

This release improves the installation experience and documentation for Kuberise.io by switching the install script from positional arguments to named flags, clarifying prerequisites, and updating all related docs to match.

### Added
- **`cilium` and `yq` as prerequisites** - Added to `.cursorrules` and `1.index.md` so users know exactly which CLI tools to install before starting.
- **Detailed parameter descriptions** - Each install script parameter now includes a description and its default value in `2.installation.md`.

### Changed
- **Named flags in `install.sh`** - The installation script now uses `--context`, `--cluster`, `--repo`, `--revision`, `--domain`, and `--token` flags instead of positional arguments, reducing confusion and making invocations self-documenting.
- **Updated installation docs** - `2.installation.md` now reflects the new flag-based invocation with clear parameter guidance.
- **Improved local development instructions** - Clarified the steps for setting up k3d clusters and running the install script per cluster.

## [0.1.0] - 9 February 2026

### Multi-Source ArgoCD Applications and Direct External Chart References

This release is a major architectural change to how ArgoCD applications reference and install external Helm charts. The wrapper chart pattern has been replaced with multi-source ArgoCD applications that reference external charts directly, eliminating subchart value nesting and enabling split-repo topologies. All decisions are documented in ADR-0014.

### Added
- **Multi-source ArgoCD applications** — Helm-type apps now use `spec.sources` (plural) with a chart source and a separate `ref: values` source, enabling value files to reside in a different repository.
- **Direct external chart references** — External charts are referenced directly in `app-of-apps/values-base.yaml` via `chart`, `repoURL`, and `targetRevision` fields, removing the need for wrapper charts.
- **Operator + config chart separation** — Five components have been split into operator and config applications: `cert-manager-config`, `keycloak-config`, `metallb-config`, `pgadmin-config`, and `k8sgpt-config`. Sync waves control deployment ordering.
- **Split-repo topology support** — New `valuesRepoURL` and `valuesTargetRevision` fields allow per-application override of the values repository, enabling developer-owned configuration in separate repos.
- **ADR-0014** documenting the rationale and consequences of this migration.

### Changed
- **Directory rename: `templates/` to `charts/`** — The top-level directory now only contains local Helm charts, kustomize apps, and config charts.
- **Value file un-nesting** — All value files across all clusters have been un-nested, removing the subchart alias prefix. Values are now passed directly to upstream charts as documented by their maintainers.
- **ArgoCD template** — Value file paths now use `$values/` prefix instead of relative `../../` paths. Non-Helm apps (kustomize, raw) continue using single-source `spec.source`.
- **`scripts/upgrade.sh` rewritten** — Now reads chart references from `app-of-apps/values-base.yaml` instead of scanning for `Chart.yaml` files in wrapper directories.

### Removed
- **All wrapper charts** — 28+ `Chart.yaml` files under `templates/` that listed external charts as dependencies have been removed.
- **`templates/` directory** — Replaced by `charts/` containing only local and config charts.

### Breaking Changes
- All value files have been un-nested (subchart alias prefix removed). Existing clusters must be redeployed or carefully migrated.
- The `templates/` directory path no longer exists; references must be updated to `charts/`.

## [0.0.8] - 8 February 2026

### Refactored ArgoCD App-of-Apps Template

This release is a major refactoring of the ArgoCD Application template and the overall app-of-apps configuration. All decisions are documented as Architecture Decision Records (ADR-0001 through ADR-0013).

### Added
- **JSON Schema validation** (`values.schema.json`) for ArgoCD Application definitions to catch typos and misconfigurations early.
- **Declarative AppProject** managed as a Helm template instead of imperatively in `install.sh`.
- **Retry with exponential backoff** on sync failures (5 retries, 10s–3m).
- **`global.clusterName`** injected as a Helm parameter into all downstream charts.
- **`team` label** per application (defaults to `platform`) for team-based filtering and access control.
- **`values` and `valuesFolder` fields** for flexible value file overrides per application.
- **`revisionHistoryLimit`** (default 3) to reduce etcd bloat, overridable per app.
- **`cilium` and `aws-lb-controller`** added as available platform components (disabled by default).
- 13 Architecture Decision Records documenting all design choices.

### Changed
- **`ignoreMissingValueFiles: true`** — ArgoCD now silently skips missing cluster-specific value files.
- **`serverSideApply`** separated into its own boolean (defaults to `true`); `syncOptions` is now purely additive.
- **`allowEmpty: false`** on automated sync to prevent accidental deletion of all resources.
- **Dynamic path resolution** using Helm `tpl` function for paths containing template expressions.
- `install.sh` updated to render and apply the AppProject via Helm.

### Removed
- ~100 empty cluster-specific value files across `aks`, `eks`, `gke`, `airgap`, and `dev-*` directories, now unnecessary thanks to `ignoreMissingValueFiles`.

## [0.0.7] - 4 July 2024

New Features and Integrations

 1. AKS and EKS Integration:
      Kuberise now supports seamless integration with Azure Kubernetes Service (AKS) and Amazon Elastic Kubernetes Service (EKS). This enhancement allows developers to easily deploy and manage applications on these popular cloud-based Kubernetes platforms.

 2. Domain Parameter:
      A new domain parameter has been introduced to facilitate the configuration of custom domains for your applications. This feature simplifies domain management and improves the flexibility of deployment environments.

 3. Keycloak Operator:
      Integration of the Keycloak operator for better management of authentication and authorization. This inclusion helps in simplifying the configuration and management of Keycloak, ensuring robust security for your applications.

 4. Let's Encrypt Certificate Integration:
      Integration of Let's Encrypt certificates for both staging and production environments. This ensures that applications deployed on cloud platforms have secure and trusted HTTPS connections by default.

Improvements

 5. Default Values for Platform Services:
      Default values have been provided for all platform services to streamline the installation process. These pre-configured defaults ensure that the platform services are set up with optimal settings, reducing the need for manual configuration and speeding up deployment.

## [0.0.6] - 21 June 2024

New Features and Enhancements:

1. kuberise.dev Ingress for Minikube Cluster

We've added kuberise.dev ingress to the Minikube cluster, making it easier for you to manage and expose your applications within your Minikube environment.

2. External CA Injection

You can now inject an External Certificate Authority (CA) into the cluster. This feature helps you create one CA, make your computer or browser trust it, and use it consistently for self-signed certificates in your cluster and services without needing a valid DNS domain for SSL certificates and without needing to create and trust a new CA each time you run in your server.

3. pgAdmin Tool Added

The pgAdmin tool has been integrated into the platform tools. This powerful administration platform for PostgreSQL enhances your database management capabilities.


---
# Template:

## [Version Number] - Release Date

### Added
- New features or additions to the project.

### Changed
- Updates and modifications to existing functionalities.

### Deprecated
- Features that are marked for removal in a future release.

### Removed
- Features or functionalities that have been removed.

### Fixed
- Bug fixes and corrections made in this release.

### Security
- Updates and fixes related to security.
