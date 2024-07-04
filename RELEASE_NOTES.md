# Release Notes

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
