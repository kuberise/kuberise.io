# Cluster Topology

This document describes the cluster topology and multi-cluster architecture of kuberise.io.

## Overview

kuberise.io supports deploying a platform across multiple Kubernetes clusters. Each cluster runs its own ArgoCD instance that syncs from the same Git repository, with cluster-specific configuration layered on top of shared defaults.

## Cluster Naming Convention

Clusters follow the pattern `{env}-{type}-{provider}-{region}`:

- **env**: `dev`, `staging`, `prod`
- **type**: `shared` (platform services) or `app` (workloads)
- **provider**: `onprem`, `aws`, `gke`, `aks`
- **region**: `one`, `frankfurt`, `us-east-1`, etc.

## Multi-Cluster Architecture

```
                         ┌─────────────────────┐
                         │    Git Repository   │
                         │   (Single Source)   │
                         └──────────┬──────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
        ┌───────────▼───────────┐       ┌───────────▼───────────┐
        │  Shared Platform      │       │  App Cluster          │
        │  Cluster              │       │                       │
        │                       │       │                       │
        │  - ArgoCD             │       │  - ArgoCD             │
        │  - Keycloak (SSO)     │       │  - Cert-Manager       │
        │  - PostgreSQL         │       │  - Ingress (int+ext)  │
        │  - Monitoring Stack   │       │  - Promtail           │
        │  - Cert-Manager       │       │  - User Applications  │
        │  - Ingress (int+ext)  │       │                       │
        │  - Cilium (CNI)       │       │                       │
        └───────────┬───────────┘       └───────────┬───────────┘
                    │                               │
                    └────────── ClusterMesh ────────┘
                         (Cilium cross-cluster
                          connectivity)
```

## Cluster Types

### Shared Platform Cluster (`*-shared-*`)

Hosts centralized platform services consumed by app clusters. Example: `dev-shared-onprem`.

**Typical components enabled:**

| Category   | Components                                             |
|------------|--------------------------------------------------------|
| Core       | raw                                                    |
| Data       | postgres-operator, database                            |
| Network    | ingress-nginx-internal, ingress-nginx-external, cilium |
| Security   | keycloak, keycloak-config, keycloak-operator, cert-manager, cert-manager-config |
| Monitoring | kube-prometheus-stack, loki, promtail, dashboards, metrics-server |

### App Cluster (`*-app-*`)

Hosts user-facing workloads. Connects back to the shared cluster for SSO, monitoring aggregation, and shared databases. Example: `dev-app-onprem-one`.

**Typical components enabled:**

| Category   | Components                                     |
|------------|------------------------------------------------|
| Core       | raw                                            |
| Network    | ingress-nginx-internal, ingress-nginx-external |
| Security   | cert-manager, cert-manager-config              |
| Monitoring | promtail                                       |
| Apps       | show-env, frontend-https, backend              |

## Supported Providers

```
┌───────────────────┬───────────────────┬───────────────────┐
│     On-Premise    │       AWS         │      Azure        │
│                   │                   │                   │
│  k3d / k3s        │  EKS              │  AKS              │
│  metallb          │  aws-lb-controller│  (cloud LB)       │
│  cilium           │  external-dns     │  external-dns     │
│  internal-dns     │  cert-manager     │  cert-manager     │
└───────────────────┴───────────────────┴───────────────────┘
                    │                   │
                    │      Google Cloud │
                    │                   │
                    │      GKE          │
                    │      (cloud LB)   │
                    │      external-dns │
                    │      cert-manager │
                    └───────────────────┘
```

## Value File Hierarchy per Cluster

Each cluster resolves its configuration through a layered value system:

```
values/
  defaults/platform/{component}/values.yaml    <-- always loaded (base)
  {cluster}/platform/{component}/values.yaml   <-- loaded if present (override)
```

Missing cluster-specific files are silently skipped (`ignoreMissingValueFiles: true`).

## Local Development Topology

The `scripts/k3d+registry/start.sh` script creates a two-cluster local environment:

```
  Docker Host
  ┌────────────────────────────────────────────────────────────────┐
  │                                                                │
  │  Docker Network: kuberise                                      │
  │                                                                │
  │  ┌───────────────────────────┐  ┌───────────────────────────┐  │
  │  │  k3d-dev-shared-onprem    │  │  k3d-dev-app-onprem-one   │  │
  │  │                           │  │                           │  │
  │  │  Platform services:       │  │  App workloads:           │  │
  │  │  - ArgoCD                 │  │  - ArgoCD                 │  │
  │  │  - Keycloak               │  │  - show-env               │  │
  │  │  - PostgreSQL             │  │  - frontend-https         │  │
  │  │  - Prometheus + Grafana   │  │  - backend                │  │
  │  │  - Loki + Promtail        │  │  - Promtail (ships to     │  │
  │  │  - Cert-Manager           │  │    shared Loki)           │  │
  │  │  - Cilium                 │  │  - Cert-Manager           │  │
  │  └───────────────────────────┘  └───────────────────────────┘  │
  │             │                              │                   │
  │             └────── Cilium ClusterMesh ────┘                   │
  │                                                                │
  └────────────────────────────────────────────────────────────────┘
```

## GitOps Flow

Every cluster follows the same GitOps bootstrapping pattern:

```
1. install.sh runs against a cluster context
         │
         ▼
2. Creates namespaces + secrets
         │
         ▼
3. Installs Cilium via Helm (directly)
         │
         ▼
4. Installs ArgoCD via Helm (directly)
         │
         ▼
5. Deploys app-of-apps ArgoCD Application
         │
         ▼
6. ArgoCD syncs all enabled child Applications
   from the same Git repository
         │
         ▼
7. Each Application pulls:
   - Chart source (external Helm repo or local charts/)
   - Values source (values/defaults + values/{cluster})
```

## Domain Structure

Services are exposed under a cluster-specific base domain:

```
{service}.{global.domain}

Examples:
  argocd.dev.kuberise.dev
  keycloak.dev.kuberise.dev
  grafana.dev.kuberise.dev
  show-env.dev.kuberise.dev
```
