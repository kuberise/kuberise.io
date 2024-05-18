![kuberise logo](docs/images/kuberise%20logo1%20-%20horizontal.png)
# kuberise

kuberise is a free opensource internal developer platform for Kubernetes environment.

## Prerequisites

- kubectl,helm,htpasswd,git command line tools
- git repository

## Installation

- Fork the repo in your github account (or clone the repository and push it in any other code repository). Now your new repository address is `RepoURL`
- Clone the repository in your computer and enter to the kuberise folder. (`cd kuberise`)
- Choose a name for your platform like `PlatformName`
- Create a value file in app-of-apps folder with the name of `values-PlatformName.yaml` (In this file you can define which tools you want to install in your platform. This file will override default values.yaml file in that folder. You can copy current values-minikube.yaml file `cp values-minikube.yaml values-PlatformName.yaml`)
- In values folder create a new folder (or copy minikube sample folder) and call it `PlatformName`. This is the folder for values for each tool that you install in your platform. For each tool that you install there should be a folder with the same name and values.yaml inside that folder. (`cp ./values/minikube/ ./values/PlatformName`)
- Commit and push changes to your fork or your repository.
- Install kuberise (if you are using fork or your repository is public, you don't need to add Token at the end of command)

```sh
./scripts/install.sh <KubernetesContext> <PlatformName> <RepoURL> <BranchName> <RepoToken>
```

## Minikube and local installation

- After deploying to a minikube local cluster, you can run `sudo minikube tunnel` command to use the local ingress to access services. For example to go to argocd and keycloak and grafana you can use these urls and you don't need to do port-forward:

  - [http://argocd.127.0.0.1.nip.io](http://argocd.127.0.0.1.nip.io)
  - [http://grafana.127.0.0.1.nip.io](http://grafana.127.0.0.1.nip.io)
  - [http://keycloak.127.0.0.1.nip.io](http://keycloak.127.0.0.1.nip.io)

## Architecture

### Single platform cluster

A common architecture looks like this:

- One platform cluster for platform services
- 3 separate clusters for applications and for different environment (Development, Acceptance, Production)
- The platform cluster will provide platform services for all 3 application clusters.

### Multiple platform clusters

Maybe you decide that one platform cluster for all is not safe. Then you can add one extra platform cluster.

- One platform cluster for platform services for non-production environments.
- Another platform cluster for platform services for production environment.
- 3 Application clusters for applications for different environments (Development, Acceptance, Production)

For multiple platform cluster scenario, you should create one value file for each of them in app-of-apps folder and also one folder for each platform in values folder. It will be like this:

```sh
.
├── app-of-apps
│   ├── values-NonProd.yaml
│   ├── values-Prod.yaml
│   └── values.yaml
└── values
    └── NonProd
    │ ├── keycloak
    │ ├── loki
    │ └── argocd
    └── Prod
      ├── keycloak
      ├── loki
      └── argocd
```

## How to uninstall

```sh
./scripts/uninstall.sh <KubernetesContext> <PlatformName>
```

## Platform Engineering Concept

Being a DevOps today is different than before. In the complex environment of different cloud providers and Kubernetes clusters, it is challenging to be a developer and also know how to deploy your application to these environments.

Platform teams can create an internal developer platform to abstract all the complexities of the deployment environments from the developers and help them to focus on their development. They provide a set of self-service tools, templates, best defaults and support to developers to be able to deploy their application whenever they want and to any environment they want without need to know and learn all details of the Kubernetes or different tools.

After deployment of their applications, developers can also monitor and maintain their own application themselves. kuberise can help platform engineers or developers to create an internal developer platform for their teams.

## kuberise features

kuberise will deploy several tools to provide a developer environment in your Kubernetes cluster.

- You can choose which tool you want to install
- Are tools are common open source projects that are popular in IT environments.
- There is no lock-in in kuberise. After deployment of kuberise, you will have the full control of your environment and shape your environment to fit you best.
- kuberise is built based on GitOps best practices. The repository is the only source of truth and you can track the changes and avoid any manual changes in the cluster.

## kuberise tools

These tools are currently included in kuberise and more tools will be included in the future:

### CD (Continuous Deployment)

- ArgoCD

### Observability

- Grafana
- Loki
- Prometheus
- Promtail

### Authentication and Authorization and Security

- Keycloak
- sealed-secret
- cert-manager

### Data

- PostgreSQL

### Networking

- Ingress-nginx
