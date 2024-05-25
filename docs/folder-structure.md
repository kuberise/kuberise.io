# Kuberise

Kuberise is an open-source project that leverages Kubernetes for deploying and managing both platform services and microservices. The configuration for these services is managed through multiple `values.yaml` file.

## Architecture

The architecture of Kuberise is designed to be modular and scalable, allowing for the deployment of a variety of services into multiple clusters. The services are divided into two main categories:

1. **Platform Services**: These are common services that are used across different applications, such as Gitea and Cloudnative-pg and Grafana. Usually these services are deployed once and used for multiple environments. For example microservices that are deployed in different environments (like dev, tst, prd) use the same Grafana that is deployed in platform cluster. Or platform services can be deployed twice, one for non production environments and one dedicated to production environment to be safer in production.

The folder structure for platform services are `values/platform_name/service_name/values.yaml`. For example if you deploy your platform services in a cluster called minikube and you have a gitea service then the values for that service is in `values/minikube/gitea/values.yaml` file. Assume you want to have one platform cluster for non-prod environments and one platform cluster for prod and your platform is minikube. Then you need to copy the whole `values/minikube` folder and call them `values/minikube-nonprod` and `values/minikube-prod`

2. **Microservices**: These are application-specific services developed by your company as the business applications, such as the `todolist-frontend` service. The values folder for these services are separated from the values folder of the platform services. The folder structure is `values/microservices/dev/todolist/backend/values.yaml` and then you will add all values for all microservices here then when you want to start a new environment like `tst` you need to duplicate the `values/microservices/dev` and rename it to `values/microservices/tst` and then modify the values for this environment and then repeat this for more environments like `prd`

## Configuration


Here is an example of how to configure a platform service (Gitea) defaults and a microservice (`todolist-frontend`) defaults in `app-of-apps/values.yaml:

```yaml
gitea:
  enabled: false
  repoURL: https://dl.gitea.io/charts
  namespace: gitea
  targetRevision: 10.1.1
  chart: gitea
  
todolist-frontend-dev:
  enabled: false
  path: apps/todolist-frontend
  values: microservices/dev/todolist/frontend/values.yaml

todolist-frontend-prd:
  enabled: false
  path: apps/todolist-frontend
  values: microservices/prd/todolist/frontend/values.yaml
```

Then you can overwrite those default values for each platform cluster. For example assume that I have a minikube platform cluster in my local computer for dev environment and an azure platform cluster for production. I would like to enable gitea in my local minikube and disable it in my production platform cluster in azure. I would like to deploy all microservices in the same cluster as platform (They could be deployed to separate cluster as well). Then I will add two more values file in my app-of-apps folder for each platform cluster. 

 `values-PlatformMinikube.yaml` for the local minikube cluster as my dev environment: 

```yaml
gitea:
  enabled: true
  
todolist-frontend-dev:
  enabled: true
```

You can see that the `enabled` value in default file is false, it means that I need to enable them for each platform I need. Here I need to enable gitea and todolist-frontend-dev. 

 `values-PlatformAzure.yaml` for the Azure AKS cluster as my production environment: 

```yaml
todolist-frontend-prd:
  enabled: true
```

For production I don't need gitea, so I don't enable it and I just need to enable my microservices for production. 