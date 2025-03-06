# Kuberise Helm Chart

This Helm chart is an alternative installation method for the Kuberise platform, providing the same functionality as the `install.sh` script in a more declarative way.

## Prerequisites

- Kubernetes cluster
- Helm 3+
- kubectl
- Access to a Git repository containing platform configurations

## Installation

```bash
# Add the repository
helm repo add kuberise https://kuberise.github.io/charts

# Install the chart
helm install kuberise kuberise/kuberise \
  --set global.platformName=my-platform \
  --set global.domain=example.com \
  --set global.adminPassword=securePassword \
  --set git.repoURL=https://github.com/your-org/your-repo.git \
  --set git.targetRevision=main \
  --set git.repositoryToken=your-token
```

## Values

| Key | Description | Default |
|-----|-------------|---------|
| `global.platformName` | Name of the platform instance | `local` |
| `global.domain` | Base domain for all services | `onprem.kuberise.dev` |
| `global.adminPassword` | Admin password for services | `admin` |
| `git.repositoryToken` | Token for Git repository access | `""` |
| `git.repoURL` | Git repository URL | `https://github.com/kuberise/kuberise.git` |
| `git.targetRevision` | Git branch or tag | `HEAD` |
| `global.database.superuserPassword` | PostgreSQL superuser password | `superpassword` |
| `global.database.appUsername` | PostgreSQL application username | `application` |
| `global.database.appPassword` | PostgreSQL application password | `apppassword` |
| `cloudflare.enabled` | Enable Cloudflare integration | `false` |
| `cloudflare.apiToken` | Cloudflare API token | `""` |
| `openai.enabled` | Enable OpenAI integration for k8sgpt | `false` |
| `openai.apiKey` | OpenAI API key | `""` |
| `ca.enabled` | Enable self-signed CA setup | `true` |

## Features

This Helm chart provides:

1. Namespaces creation for all platform components
2. Secret management for database, authentication, and API tokens
3. Self-signed CA certificate generation for secure communication
4. ArgoCD installation and configuration
5. App of Apps pattern setup to deploy the full platform
6. OIDC authentication configuration for Kubernetes

## Additional Configuration

For advanced configurations, refer to the `values.yaml` file and override values as needed.
