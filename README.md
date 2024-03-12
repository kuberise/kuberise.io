# kuberise

kuberise is a free opensource internal developer platform for Kubernetes environment.

## Installation

If you don't have ArgoCD installed, you need to install it first:
```
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

ADMIN_PASSWORD=admin
BCRYPT_HASH=$(htpasswd -nbBC 10 "" $ADMIN_PASSWORD | tr -d ':\n' | sed 's/$2y/$2a/')
helm upgrade --install -n argocd argocd argo/argo-cd --version 6.1.0  --set configs.secret.argocdServerAdminPassword=$BCRYPT_HASH --create-namespace
```

Now you can install kuberise helm chart:
```
helm repo add kuberise https://kuberise.github.io/kuberise/
helm repo update
helm install kuberise-dev kuberise/kuberise -n argocd
```
kuberise should be installed in the argocd namespace. If your argocd is in another namespace, then install kuberise in that namespace.

## How to uninstall

```
helm uninstall kuberise-dta -n argocd
```

## How to create a values repository

If you want to modify the values of different helm charts, you need to create a fork or clone of the repository and push it to your git repository and give the address of that repository to your app of apps helm chart.


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

### Authentication and Authorisation and security
- Keycloak
- sealed-secret
- cert-manager
### Data
- PostgreSQL

### Networking
- Ingress-nginx
