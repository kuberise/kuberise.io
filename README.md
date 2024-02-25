# kuberise

kuberise is an internal developer platform that installs core apps into a kubernetes cluster and makes it ready to deploy custom services. Then developers can use this platform to deploy their services to different environments.

## Use case

Assume that there are multiple business or developer teams called blue, red, green, etc. There is one platform team that provides the kubernetes platform and platform tools and automation so that developer teams can focus on their own business applications and development.

Platform team creates a namespace for each team and each team can deploy their services to only their own namespace.

There are two Kubernetes clusters one for dev/test/acc (dta) and another one dedicated to the production (prd) environment. dev/test/acc in dta cluster are separated in different namespaces. They use one cluster for those environment to save cost. otherwise they can have separate cluster for each environment.

## Values

You can define a separate repository for values. If you do so, you can update the main platform source without affecting your values.

## Installation

You need to have kubectl and helm commands installed in your local environment then use these commands to install and configure argocd. Then argocd will pull the code from the repository and deploy apps to the cluster.

Also create an environment variable ADMIN_PASSWORD for argocd admin password

```bash
cicd/scripts/install.sh <Kubernetes context> <environment name> <git repository token>
```

example command for dta and prd environments are:

dta:
```
cicd/scripts/install.sh minikube-dta dta $GITHUB_TOKEN
```

prd:
```
cicd/scripts/install.sh minikube-prd prd $GITHUB_TOKEN
```
## nip.io Ingress

The service type for dashboards should be LoadBalancer.

First run `minikube tunnel -p <profile>`. Then use the ingress address like:

ArgoCD dashboard: http://argocd.127.0.0.1.nip.io

In some networks nip.io for 127.0.0.1 doesn't work and you have to change you internet network (for example use you mobile hotspot network) or change your dns server settings to google dns server.


Todo:
- [X] Connect keycloak to cloudnative-pg
- [ ] Deploy Hashicorp Vault for secret management.
- [ ] Each service use a different database and username and credentials for connecting to the database
