![kuberise logo](logo.svg)
# kuberise.io

**A free, open-source internal developer platform for Kubernetes.**

kuberise.io gives you a production-ready platform on any Kubernetes cluster -- local, cloud, or on-prem -- in minutes. It bundles battle-tested open-source tools (ArgoCD, Prometheus, Keycloak, Backstage, and many more) so your team can focus on building business applications instead of wiring up infrastructure.

## Why kuberise.io?

- **Fast setup** -- go from an empty cluster to a fully configured platform with a single command.
- **GitOps by default** -- every change is declarative, version-controlled, and auditable via ArgoCD.
- **Multi-cluster, multi-cloud** -- manage dev, staging, and production clusters across providers with the same codebase.
- **Modular** -- enable only the components you need; disable everything else.
- **No vendor lock-in** -- pure open-source stack, runs anywhere Kubernetes runs.

## Quick Start

### Prerequisites

- CLI tools: `kubectl`, `helm`, `htpasswd`, `openssl`, `cilium`, `yq`, `git`
- A Kubernetes cluster ([k3d](https://k3d.io), [kind](https://kind.sigs.k8s.io), minikube, or any cloud provider)

### Install the `kr` CLI

```bash
curl -sSL https://kuberise.io/install | sh
```

To install a specific version, set `KR_VERSION` for the shell that runs the script: `curl -sSL https://kuberise.io/install | KR_VERSION=0.3.0 sh`

### Bootstrap and Deploy

```bash
# 1. Bootstrap the cluster (namespaces, secrets, CA, ArgoCD)
kr init --context <CONTEXT> --cluster <NAME> --domain <DOMAIN>

# 2. Deploy the platform (app-of-apps layer)
kr deploy --context <CONTEXT> --cluster <NAME> \
  --repo <REPO_URL> --revision <REVISION> --domain <DOMAIN> \
  [--token <TOKEN>]
```

| Command | Flag | Description |
|---------|------|-------------|
| `init` | `--context` | **(required)** Kubernetes context name |
| `init` | `--domain` | **(required)** Base domain for all services |
| `init` | `--cluster` | Cluster name (default: `onprem`) |
| `init` | `--admin-password` | Admin password (default: `admin`, warns) |
| `deploy` | `--context` | **(required)** Kubernetes context name |
| `deploy` | `--repo` | **(required)** Git repository URL |
| `deploy` | `--cluster` | Cluster name (default: `onprem`) |
| `deploy` | `--domain` | Base domain (default: `onprem.kuberise.dev`) |
| `deploy` | `--revision` | Branch, tag, or commit SHA (default: `HEAD`) |
| `deploy` | `--name` | Layer identifier for multi-layer setups (default: `shared`) |
| `deploy` | `--token` | Git token for private repositories (optional) |

Run `kr init --help` or `kr deploy --help` for the full list of flags.

**Example** using a local k3d cluster:

```bash
kr init --context k3d-dev --cluster dev-app-onprem-one \
  --domain k3d.kuberise.dev

kr deploy --context k3d-dev --cluster dev-app-onprem-one \
  --repo https://github.com/<you>/kuberise.io.git \
  --revision main --domain k3d.kuberise.dev
```

### Multi-Layer Deployment

Deploy multiple layers (OSS, Client, Teams, etc.) by calling `kr deploy` with different `--name` values:

```bash
# Default layer
kr deploy --context k3d-dev --cluster dev-app-onprem-one \
  --repo https://github.com/kuberise/kuberise.io.git \
  --name default ...

# Client layer
kr deploy --context k3d-dev --cluster dev-app-onprem-one \
  --repo https://github.com/org/client.git \
  --name client-name --token $TOKEN ...
```

### Uninstall

```bash
kr uninstall --context <CONTEXT> --cluster <NAME>
```

## Documentation

Full documentation, architecture decisions, and guides are available at **[kuberise.io](https://kuberise.io)**.

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request. For major changes, please open an issue first to discuss what you would like to change.

## License

kuberise.io is dual-licensed:

- **Open-source use** -- The source code is available under the [GNU Affero General Public License v3.0 (AGPL-3.0)](LICENSE). You are free to read, use, modify, and distribute the software for personal, educational, or internal evaluation purposes under the terms of the AGPL-3.0.

- **Commercial use** -- If you want to use kuberise.io to provide commercial services, sell products, or run a business without complying with the AGPL-3.0 obligations (such as releasing your modifications under the same license), you must obtain a commercial license. See [COMMERCIAL_LICENSE.md](COMMERCIAL_LICENSE.md) for details, or contact us at **license@kuberise.io**.

By contributing to this project, you agree that your contributions will be licensed under the AGPL-3.0 and that the project maintainers may offer them under a commercial license as well.
