# ADR-0003: Inject global.clusterName as a Helm Parameter into All Applications

## Status

Accepted

## Context

The ArgoCD app-of-apps template already injects `global.domain` as a Helm parameter into every generated ArgoCD Application. This makes the base domain available to all downstream charts without requiring it in every values file.

The cluster name (`global.clusterName`) is a fundamental piece of identity in a multi-cluster platform, yet it was only available inside the app-of-apps template itself (for constructing value file paths and the ArgoCD project name). Downstream Helm charts had no standard way to know which cluster they were deployed to unless the cluster name was manually duplicated into each component's values file.

## Decision

We inject `global.clusterName` as an additional Helm parameter alongside `global.domain` in the ArgoCD Application template:

```yaml
parameters:
  - name: global.domain
    value: {{ $.Values.global.domain }}
  - name: global.clusterName
    value: {{ $.Values.global.clusterName }}
```

This makes `{{ .Values.global.clusterName }}` available in every Helm-type downstream chart with no additional configuration.

### Use cases enabled

#### 1. Observability labels and metadata

Components like Prometheus, Loki, and Promtail can tag metrics and logs with the cluster name. In a multi-cluster setup where the shared cluster aggregates observability data from multiple app clusters (e.g., via Cilium ClusterMesh), the cluster label is essential for distinguishing data sources and filtering dashboards.

#### 2. Cross-cluster service discovery

When using Cilium ClusterMesh, services can be annotated with the originating cluster name to enable cluster-aware routing or DNS entries.

#### 3. Resource naming to avoid collisions

When resources from multiple clusters end up in a shared system (e.g., shared Vault, shared Keycloak, shared Git server), the cluster name can namespace resources such as Keycloak realms, Vault secret paths, or Git repository prefixes, preventing cross-cluster collisions.

#### 4. Ingress and DNS differentiation

While `global.domain` handles the base domain, some components may need cluster-specific subdomains (e.g., `grafana.{clusterName}.{domain}`) in environments where multiple clusters share the same base domain.

#### 5. Backup and storage path organization

Components like Loki, MinIO, or PostgreSQL backup jobs can use the cluster name to organize storage paths (e.g., `s3://backups/{clusterName}/postgres/`), preventing cross-cluster data overwrites.

#### 6. Conditional logic in templates

Downstream charts can implement cluster-aware behavior without hard-coded cluster-specific values files:

```yaml
{{- if eq .Values.global.clusterName "dev-shared-onprem" }}
  # shared-cluster-specific configuration
{{- end }}
```

#### 7. Notifications and alerts

Alert messages and ArgoCD notifications can include the cluster name so operators immediately know which cluster an issue originated from.

## Consequences

- Every Helm-type ArgoCD Application automatically receives `global.clusterName` as a parameter.
- Downstream charts can reference `{{ .Values.global.clusterName }}` without any values file changes.
- The cluster identity is consistent across all components, eliminating the risk of mismatched or manually duplicated cluster names in individual values files.
- Non-Helm application types (kustomize, raw) do not receive this parameter, as they do not use Helm's parameter injection mechanism.
