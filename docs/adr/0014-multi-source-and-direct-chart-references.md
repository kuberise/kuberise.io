# ADR-0014: Multi-Source Applications and Direct External Chart References

## Status

Accepted

## Context

The platform previously used "wrapper charts" to install external Helm charts. Each external chart (e.g., cert-manager, ingress-nginx, kube-prometheus-stack) had a local directory under `templates/` containing a `Chart.yaml` with the external chart listed as a dependency. This pattern had several drawbacks:

1. **Indirect dependency management.** Upgrading an external chart required editing `Chart.yaml`, running `helm dependency update`, and committing the `Chart.lock` and downloaded `.tgz` archive. This added friction and binary artifacts to the Git repository.

2. **Value nesting.** Because external charts were installed as subcharts, all values had to be nested under the subchart alias key (e.g., `ingress-nginx:`, `keycloakx:`, `kube-prometheus-stack:`). This was confusing for users who expected to pass values directly as documented by the upstream chart.

3. **Mixed responsibilities.** Some wrapper charts bundled both the external chart dependency AND custom Kubernetes resources (e.g., cert-manager included ClusterIssuers/Certificates, keycloak included KeycloakClients/Realms). This coupled operator installation with operator configuration, making it harder to reason about sync ordering and failure isolation.

4. **Inconsistent architecture.** Some components already separated operator from configuration (e.g., `kyverno` + `policy`, `postgres-operator` + `database`), but others did not (e.g., `cert-manager`, `keycloak`). The codebase lacked a consistent pattern.

5. **No split-repo support.** The single-source design prevented value files from residing in a separate Git repository, which blocks developer-owned configuration (ADR-0008).

## Decision

### 1. Multi-source ArgoCD Applications

All Helm-type applications now use `spec.sources` (plural) instead of `spec.source` (singular). Each Helm application has two sources:

- **Chart source**: Either a direct reference to an external Helm chart repository (via `chart` + `repoURL` + `targetRevision`) or a path to a local chart in the Git repository.
- **Values source**: A `ref: values` source pointing to the Git repository containing value files.

Value files use the `$values/` prefix to reference files from the values repository:

```yaml
sources:
  - repoURL: https://charts.jetstack.io
    chart: cert-manager
    targetRevision: v1.20.0-alpha.1
    helm:
      valueFiles:
        - $values/values/defaults/platform/cert-manager/values.yaml
        - $values/values/dev-shared-onprem/platform/cert-manager/values.yaml
  - repoURL: <git-repo>
    targetRevision: <revision>
    ref: values
```

Non-Helm applications (kustomize, raw) continue to use single-source `spec.source`.

### 2. Direct external chart references

External Helm charts are now referenced directly in `app-of-apps/values.yaml` using `chart`, `repoURL`, and `targetRevision` fields, instead of through local wrapper Chart.yaml files. For example:

```yaml
cert-manager:
  enabled: false
  chart: cert-manager
  repoURL: https://charts.jetstack.io
  targetRevision: v1.20.0-alpha.1
```

This eliminates the need for wrapper charts, `Chart.lock` files, and downloaded chart archives in the Git repository.

### 3. Operator + config chart separation

Components that previously bundled external chart dependencies with custom Kubernetes resources are now split into two ArgoCD Applications:

| Component | Operator App | Config App |
|-----------|-------------|------------|
| cert-manager | `cert-manager` (upstream chart) | `cert-manager-config` (ClusterIssuers, Certificates) |
| keycloak | `keycloak` (upstream chart) | `keycloak-config` (Realm, Clients, Users) |
| metallb | `metallb` (upstream chart) | `metallb-config` (IPAddressPool, L2Advertisement) |
| pgadmin | `pgadmin` (upstream chart) | `pgadmin-config` (ConfigMap with OAuth2 config) |
| k8sgpt | `k8sgpt` (upstream chart) | `k8sgpt-config` (K8sGPT CRs for OpenAI/Ollama) |

Config charts use `syncWave: 2` (default is 1) to ensure the operator and its CRDs are installed before the configuration resources.

This is consistent with the existing patterns: `kyverno` + `policy`, `postgres-operator` + `database`, `external-secrets` + `secrets-manager`, `vault` + `secrets`.

### 4. Value file un-nesting

Since external charts are no longer installed as subcharts, values no longer need the subchart alias prefix. All value files have been un-nested:

```yaml
# Before (subchart nesting)
ingress-nginx:
  controller:
    metrics:
      enabled: true

# After (direct chart values)
controller:
  metrics:
    enabled: true
```

### 5. Directory rename: `templates/` to `charts/`

The top-level `templates/` directory has been renamed to `charts/` to better reflect its purpose. It now contains only local Helm charts and kustomize applications that are not available from external repositories:

- Local charts: `backstage`, `generic-deployment`, `ingresses`, `kube-prometheus-stack-crds`, `secrets-manager`, `team-setup`, `teams-namespaces`, `tekton-operator`
- Kustomize apps: `dashboards`, `hello`
- Config charts: `cert-manager-config`, `keycloak-config`, `metallb-config`, `pgadmin-config`, `k8sgpt-config`

### 6. Split-repo topology support

The multi-source architecture enables each application to optionally use a different repository for its value files via `valuesRepoURL` and `valuesTargetRevision` fields. When `global.spec.values.repoURL` equals `global.spec.source.repoURL` (the default), behavior is functionally identical to the previous design.

### 7. Upgrade script

The `scripts/upgrade.sh` script has been rewritten to read chart references from `app-of-apps/values.yaml` instead of scanning for `Chart.yaml` files in wrapper chart directories.

## Consequences

### Positive

- **Simpler upgrades.** Updating an external chart version is a one-line change to `targetRevision` in `values.yaml`. No `helm dependency update`, no lock files, no binary archives.
- **Cleaner values.** Users pass values exactly as documented by upstream charts, without subchart nesting.
- **Consistent separation.** All components now follow the operator + config pattern where applicable.
- **Split-repo ready.** Developer teams can own their application values in separate repositories.
- **Smaller repository.** No more downloaded chart archives (`charts/*.tgz`) or `Chart.lock` files.
- **Better failure isolation.** Operator installation failures don't block config resources and vice versa.

### Negative

- **More ArgoCD Applications.** Five additional config applications (cert-manager-config, keycloak-config, metallb-config, pgadmin-config, k8sgpt-config). This is a minor increase in the ArgoCD UI.
- **Sync wave dependency.** Config charts depend on their operator being ready (CRDs must exist). The `syncWave: 2` annotation handles this, but it adds an ordering constraint.
- **Breaking change for existing clusters.** All value files have been un-nested, and wrapper chart directories have been removed. Existing clusters must be redeployed or carefully migrated.
- **ArgoCD multi-source maturity.** While multi-source is now generally available in ArgoCD 2.14+, some UI features may not fully support it yet.
