# External Secrets Manager

This chart demonstrates how to use [external-secrets](https://external-secrets.io/) to:

1. Generate random secrets and passwords using ClusterGenerator
2. Copy these secrets across different namespaces using ClusterExternalSecret
3. Set up proper RBAC permissions for cross-namespace secret access

## Key Features

- Generates random passwords for database users and OAuth2 clients
- Copies secrets to relevant namespaces (e.g. database credentials to application namespaces)
- Sets up ClusterSecretStore to enable cross-namespace secret access
- Configures necessary ServiceAccounts and RBAC permissions

## Usage

By default, this chart is disabled for simplicity and random secrets are generated in the install script.
Then external-secrets can be disabled and it is not an essential part of the platform.
The main usage of external-secrets is to sync secrets between external secret stores like Azure Key Vault and Kubernetes.
