# Component Dependency Graph

This document describes the dependencies and deployment ordering between platform components in kuberise.io.

## Sync Wave Ordering

ArgoCD deploys components in sync wave order. Lower waves deploy first. Most components default to wave 1. Components that depend on CRDs or operators from another component use wave 2.

```
Wave 1 (Operators & Core)          Wave 2 (Configs & Dependents)
──────────────────────────────     ───────────────────────────────
cert-manager                 ───►  cert-manager-config
keycloak-config              ───►  keycloak
postgres-operator            ───►  database
metallb                      ───►  metallb-config
kube-prometheus-stack-crds   ───►  kube-prometheus-stack
k8sgpt                       ───►  (uses k8sgpt-config at wave 1*)
```

*keycloak-config is at wave 1 and keycloak at wave 2 because the config chart creates the TLS certificate that keycloak needs at startup.

## Operator + Config Chart Pattern

Components that install a CRD-based operator and also need custom CRD instances are split into two ArgoCD Applications:

```
┌─────────────────────┐           ┌────────────────────────┐
│  Operator App       │  wave 1   │  Config App            │  wave 2
│  (upstream chart)   │ ────────► │  (local chart in       │
│                     │           │  charts/{name}-config) │
│  Installs:          │           │  Installs:             │
│  - CRDs             │           │  - CRD instances       │
│  - Controllers      │           │  - Custom resources    │
│  - RBAC             │           │                        │
└─────────────────────┘           └────────────────────────┘
```

### Examples

| Operator App (wave 1)        | Config App (wave 2)      | Config creates                        |
|------------------------------|--------------------------|---------------------------------------|
| cert-manager                 | cert-manager-config      | ClusterIssuer, Certificate            |
| postgres-operator            | database                 | Cluster (CNPG database instances)     |
| metallb                      | metallb-config           | IPAddressPool, L2Advertisement        |
| keycloak-config* (wave 1)    | keycloak (wave 2)        | *Config creates TLS cert for Keycloak |

## Component Categories and Dependencies

### Infrastructure Layer (deployed first)

```
┌───────────┐     ┌─────────┐     ┌───────────────────┐
│  cilium   │     │ metallb │────►│ metallb-config    │
│ (via Helm │     └─────────┘     │ (IP pools, L2)    │
│  direct)  │                     └───────────────────┘
└───────────┘
```

Cilium is installed directly via Helm (not through ArgoCD) during `install.sh` because it provides the CNI that all other pods need.

### Certificate Management

```
┌──────────────┐          ┌──────────────────────┐
│ cert-manager │ ────────►│ cert-manager-config  │
│ (jetstack)   │  wave 1  │ (local chart)        │
└──────────────┘    to    │ - ClusterIssuer      │
                  wave 2  │ - CA Certificate     │
                          └──────────────────────┘
                                   │
                     provides TLS certificates to:
                        │          │          │
                   ┌────┴───┐ ┌────┴───┐ ┌────┴───┐
                   │keycloak│ │ingress │ │argocd  │
                   └────────┘ └────────┘ └────────┘
```

### Ingress Layer

```
┌─────────────────────────┐     ┌─────────────────────────┐
│ ingress-nginx-external  │     │ ingress-nginx-internal  │
│ (public traffic)        │     │ (cluster-internal)      │
└────────────┬────────────┘     └────────────┬────────────┘
             │                               │
             └────────── both use ───────────┘
             │                               │
    ┌────────▼────────┐            ┌─────────▼───────┐
    │ external-dns    │            │ internal-dns    │
    │ (public DNS)    │            │ (private DNS)   │
    └─────────────────┘            └─────────────────┘
```

### Identity and Access Management

```
┌──────────────────┐     ┌──────────────────┐     ┌───────────┐
│ keycloak-config  │────►│ keycloak         │────►│ oauth2-   │
│ (wave 1)         │     │ (wave 2)         │     │ proxy     │
│ - TLS cert       │     │ - SSO provider   │     └─────┬─────┘
└────────┬─────────┘     └─────────┬────────┘           │
         │                         │              protects access to:
         │                         │              - dashboards
  ┌──────▼──────────┐      ┌───────▼─────────┐    - pgadmin
  │ keycloak-       │      │ OIDC clients:   │    - backstage
  │ operator        │      │ - ArgoCD        │
  │ (manages        │      │ - Grafana       │
  │  realms/users)  │      │ - PGAdmin       │
  └─────────────────┘      │ - OAuth2-Proxy  │
                           └─────────────────┘
```

### Data Layer

```
┌───────────────────┐          ┌──────────────────┐
│ postgres-operator │ ────────►│ database         │
│ (CloudNative-PG)  │  wave 1  │ (CNPG Cluster    │
└───────────────────┘    to    │  instances)      │
                       wave 2  └────────┬─────────┘
                                        │
                           creates databases for:
                           │          │          │
                      ┌────┴───┐ ┌────┴────┐ ┌───┴────┐
                      │keycloak│ │backstage│ │  gitea │
                      └────────┘ └─────────┘ └────────┘

┌─────────┐     ┌──────────────────┐
│ pgadmin │ ◄── │ pgadmin-config   │
│ (UI)    │     │ (server defs)    │
└─────────┘     └──────────────────┘

┌─────────┐     ┌──────────────────┐
│ redis   │     │ minio            │
│ (cache) │     │ (object storage) │
└─────────┘     └──────────────────┘
```

### Monitoring Stack

```
┌────────────────────────────┐          ┌────────────────────────┐
│ kube-prometheus-stack-crds │ ────────►│ kube-prometheus-stack  │
│ (wave 1)                   │  wave 1  │ (wave 2)               │
└────────────────────────────┘    to    │ - Prometheus           │
                                wave 2  │ - Grafana              │
                                        │ - Alertmanager         │
                                        └────────┬───────────────┘
                                                 ▲
                                                 │
                        ┌────────────┬───────────┴───────────┐
                        │            │                       │
                  ┌─────┴────┐ ┌─────┴─────┐          ┌──────┴──────┐
                  │ promtail │ │ loki      │          │ dashboards  │
                  │ (log     │ │ (log      │          │ (Grafana    │
                  │  shipper)│ │  storage) │          │  dashboards)│
                  └────┬─────┘ └─────▲─────┘          └─────────────┘
                       │             │
                       └─────────────┘
                      ships logs to Loki

┌────────────────┐
│ metrics-server │  (standalone, no dependencies)
└────────────────┘

┌────────────────┐
│ opencost       │  (reads from Prometheus)
└────────────────┘
```

### Security and Policy

```
┌─────────────────┐     ┌───────────────────┐
│ external-secrets│     │ sealed-secrets    │
│ (ESO)           │     │ (Bitnami)         │
└────────┬────────┘     └─────────┬─────────┘
         │                        │
         └─── alternative secret management ─────┐
         │                                       │
┌────────▼──────────┐                    ┌───────▼─────────┐
│ vault             │                    │ secrets         │
│ (HashiCorp)       │                    │ (raw manifests) │
└────────┬──────────┘                    └─────────────────┘
         │
┌────────▼─────────────────┐
│ vault-secrets-operator   │
└──────────────────────────┘

┌─────────┐     ┌─────────┐
│ kyverno │ ──► │ policy  │
│ (engine)│     │ (rules) │
└─────────┘     └─────────┘

┌────────────┐
│ neuvector  │  (container runtime security, standalone)
└────────────┘
```

### Developer Tools

```
┌───────────┐     ┌──────────┐     ┌───────────────┐
│ backstage │ ──► │ gitea    │     │ argocd-image- │
│ (portal)  │     │ (git)    │     │ updater       │
└───────────┘     └──────────┘     └───────────────┘

┌──────────┐     ┌─────────────────┐
│ k8sgpt   │ ──► │ k8sgpt-config   │
│(AI debug)│     │ (analyzer CRs)  │
└──────────┘     └─────────────────┘

┌──────────┐     ┌──────────┐
│ ollama   │     │ vcluster │  (virtual clusters)
│ (LLM)    │     └──────────┘
└──────────┘
```

### Team Management

```
┌──────────────────┐     ┌─────────────┐
│ teams-namespaces │ ──► │ team-setup  │
│ (creates NS per  │     │ (RBAC,      │
│  team)           │     │  quotas)    │
└──────────────────┘     └─────────────┘
```

## Full Deployment Order

The `install.sh` script bootstraps components in this order before ArgoCD takes over:

```
1. Namespaces (created directly via kubectl)
   │
2. Secrets (repo access, CA certs, DB credentials, OAuth clients)
   │
3. Cilium (installed via Helm, provides CNI)
   │
4. ArgoCD (installed via Helm, enables GitOps)
   │
5. app-of-apps Application (triggers ArgoCD sync)
   │
   ├── ArgoCD sync wave 1 ──┐
   │   - cert-manager       │
   │   - keycloak-config    │
   │   - postgres-operator  │
   │   - metallb            │
   │   - prom-stack-crds    │
   │   - ingress-nginx-*    │
   │   - all other wave-1   │
   └────────────────────────┘
   │
   ├── ArgoCD sync wave 2 ──┐
   │   - cert-manager-config│
   │   - keycloak           │
   │   - database           │
   │   - metallb-config     │
   │   - prom-stack         │
   │   - all other wave-2   │
   └────────────────────────┘
```

## Multi-Source Application Flow

Each Helm-type ArgoCD Application uses two sources (ADR-0014):

```
ArgoCD Application
  │
  ├── Source 1: Chart
  │   - External: repoURL + chart + targetRevision
  │   - Local:    charts/{name} path
  │
  └── Source 2: Values (ref: values)
      - values/defaults/platform/{name}/values.yaml  (always loaded)
      - values/{cluster}/platform/{name}/values.yaml  (if exists)
```

Non-Helm apps (kustomize, raw) use a single source pointing to the local path.
