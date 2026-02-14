# Release Notes

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
- **Direct external chart references** — External charts are referenced directly in `app-of-apps/values.yaml` via `chart`, `repoURL`, and `targetRevision` fields, removing the need for wrapper charts.
- **Operator + config chart separation** — Five components have been split into operator and config applications: `cert-manager-config`, `keycloak-config`, `metallb-config`, `pgadmin-config`, and `k8sgpt-config`. Sync waves control deployment ordering.
- **Split-repo topology support** — New `valuesRepoURL` and `valuesTargetRevision` fields allow per-application override of the values repository, enabling developer-owned configuration in separate repos.
- **ADR-0014** documenting the rationale and consequences of this migration.

### Changed
- **Directory rename: `templates/` to `charts/`** — The top-level directory now only contains local Helm charts, kustomize apps, and config charts.
- **Value file un-nesting** — All value files across all clusters have been un-nested, removing the subchart alias prefix. Values are now passed directly to upstream charts as documented by their maintainers.
- **ArgoCD template** — Value file paths now use `$values/` prefix instead of relative `../../` paths. Non-Helm apps (kustomize, raw) continue using single-source `spec.source`.
- **`scripts/upgrade.sh` rewritten** — Now reads chart references from `app-of-apps/values.yaml` instead of scanning for `Chart.yaml` files in wrapper directories.

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
