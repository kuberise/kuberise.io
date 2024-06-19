![kuberise logo](docs/images/kuberise%20logo1%20-%20horizontal.png)
# Kuberise

Kuberise is a free opensource internal developer platform for Kubernetes environment. The goal is to provide tools and templates in Kubernetes environment by a fast and easy installation to help developers focus on the development of the business applications rather than installation and configuration of side tools and preparations of the environments and automation.

## Prerequisites

- CLI tools: kubectl, helm, htpasswd, git
- A Github account or another git repository system
- [K9s](https://k9scli.io/topics/install/) for dashboard (recommended)
- A [kind](https://kind.sigs.k8s.io/docs/user/quick-start#installation) kubernetes cluster for local installation (`kind create cluster`)
- [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) for loadBalancer services and ingresses.

## Installation

1. Fork the current repository [https://github.com/kuberise/kuberise](https://github.com/kuberise/kuberise) into your Github account, or clone and push it to your other git repository.
2. Run these commands (first modify the url of the repository to point to your new repository):

```bash
export GITHUB_USER=[yourUserName]
export REPO_URL=https://github.com/$GITHUB_USER/kuberise.git
git clone $REPO_URL
cd kuberise

export CONTEXT=$(kubectl config current-context)
export PLATFORM_NAME=kind-sample
export REVISION=main
export ADMIN_PASSWORD=admin
export PG_SUPERUSER_PASSWORD=superpassword
export PG_APP_PASSWORD=apppassword

./scripts/install.sh $CONTEXT $PLATFORM_NAME $REPO_URL $REVISION
```

To read more please refer to the [docs here](docs/README.md)
