# Architecture

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

In app-of-apps folder there is one `values.yaml` which is a default value file and there should be one value file for each separate platform cluster, because you have to install the app-of-apps once per platform cluster. This is equal to the number of argocd instances you have. This argocd is managing the platform services and also the microservices. Even if the miroservices are deployed into another cluster, they are deployed and managed by the argocd inside the platform cluster.

For example, assume that you have your platform cluster in azure and you call your platform "PlatformAzure", you have only one platform cluster that manages all environments of microservices and you have 3 separate clusters for your microservcies (dev,tst,prd). Then in your app-of-apps folder you will have only two value files: `values.yaml` for defaults and `values-PlatformAzure.yaml` for your one platform cluster.

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