# Quick installation for demo  (with specific set of tools)


This instruction is only for demo and it will deploy a set of default tools and you can not modify or change any value or configuration and you can not disable or enable the tools.
## Prerequisites

- CLI tools: kubectl, helm, htpasswd, git
- A local minikube kubernetes cluster (`minikube start`)

## Quick installation

Assume that you have a local minikube kubernetes cluster created by command `minikube start` , then run these commands:

```sh
export CONTEXT=$(kubectl config current-context)
export ADMIN_PASSWORD=admin
export PG_SUPERUSER_PASSWORD=superpassword
export PG_APP_PASSWORD=apppassword
git clone https://github.com/kuberise/kuberise.git
cd kuberise
./scripts/install.sh $CONTEXT local https://github.com/kuberise/kuberise.git main
```

You have to answer yes to the confirmation question and then wait few minutes to have all default tools ready. Then run this command to make a tunnel from your local host to your Kubernetes master node:

```shell
sudo minikube tunnel
```

Then you can see the dashboard of the installed service:
[https://argocd-172-19-0-3.nip.io/](https://argocd-172-19-0-3.nip.io/)
[https://backstage-172-19-0-3.nip.io/](https://backstage-172-19-0-3.nip.io/)
[http://keycloak-172-19-0-3.nip.io/](http://keycloak-172-19-0-3.nip.io/)
[https://grafana-172-19-0-3.nip.io/](https://grafana-172-19-0-3.nip.io/)
