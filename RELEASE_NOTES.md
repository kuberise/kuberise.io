# Release Notes

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
