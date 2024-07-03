![kuberise logo](docs/images/full-logo.svg)
# kuberise.io

kuberise.io is a free opensource internal developer platform for Kubernetes environment. The goal is to provide tools and templates in Kubernetes environment by a fast and easy installation to help developers focus on the development of the business applications rather than installation and configuration of side tools and preparations of the environments and automation.

## Prerequisites

- CLI tools: kubectl, helm, htpasswd, git, openssl
- A Github account or another git repository system
- [K9s](https://k9scli.io/topics/install/) for dashboard (recommended)
- A [minikube]([https://kind.sigs.k8s.io/docs/user/quick-start#installation](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fmacos%2Fx86-64%2Fstable%2Fbinary+download)) kubernetes cluster for local installation (`minikube start`)
- [cloud-provider-kind](https://github.com/kubernetes-sigs/cloud-provider-kind) for loadBalancer services and ingresses.

## Installation

1. Fork the current repository [https://github.com/kuberise/kuberise.io](https://github.com/kuberise/kuberise.io) into your Github account, or clone and push it to your other git repository.
2. Run these commands (first modify the url of the repository to point to your new repository):

```bash
export GITHUB_USER=oidcproxydotnet
export REPO_URL=https://github.com/oidcproxydotnet/OidcProxy.Net.Dev.git

export CONTEXT=$(kubectl config current-context)
export PLATFORM_NAME=oidcproxy-dev-env
export REVISION=main
export ADMIN_PASSWORD=admin
export PG_SUPERUSER_PASSWORD=superpassword
export PG_APP_PASSWORD=apppassword
export DOMAIN=minikube.kuberise.dev

./scripts/install.sh $CONTEXT $PLATFORM_NAME $REPO_URL $REVISION $DOMAIN
```

To read more please refer to the [docs here](docs/README.md)
