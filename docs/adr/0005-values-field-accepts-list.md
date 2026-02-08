# ADR-0005: The `values` Field Accepts a List of Value Files

## Status

Accepted

## Context

The ArgoCD Application template supports a `values` field that lets an application override the default two-file value hierarchy (`defaults` + `cluster`). When omitted, the template automatically constructs value file paths using the `valuesFolder` or default convention. When provided, `values` gives the author full control over which value files are used.

While the existing `valuesFolder` mechanism covers the common case, there are scenarios where a component needs values composed from multiple non-standard sources (shared library values, environment-tier layering, external chart overrides).

## Decision

The `values` field must always be a list (YAML array), even when specifying a single file. The field is never a string. This keeps the template simple and the input format consistent.

When `values` is omitted, the default behavior applies (defaults + cluster-specific files via `valuesFolder` or the standard platform convention). When `values` is provided, only the listed files are used -- the author has full control over file ordering and must explicitly include any cluster-specific files.

### Input format

```yaml
# Single file -- still a list
my-app:
  enabled: true
  values:
    - ../../values/defaults/platform/my-app/values.yaml

# Multiple files -- later files take precedence
my-frontend:
  enabled: true
  values:
    - ../../values/defaults/applications/shared-frontend/values.yaml
    - ../../values/defaults/applications/my-frontend/values.yaml
    - ../../values/my-cluster/applications/my-frontend/values.yaml
```

### Use cases enabled

#### 1. Shared library values layered with app-specific values

Multiple applications using the same Helm chart (e.g., `generic-deployment`) may share common configuration (resource limits, health checks, sidecar config) while having their own app-specific overrides:

```yaml
my-frontend:
  enabled: true
  path: templates/generic-deployment
  values:
    - ../../values/defaults/applications/shared-frontend/values.yaml
    - ../../values/defaults/applications/my-frontend/values.yaml
    - ../../values/my-cluster/applications/my-frontend/values.yaml
```

#### 2. Environment-tier values

A "production hardened" values file (stricter security contexts, higher replicas, resource limits) can be layered on top of component-specific values without duplicating settings across every production component:

```yaml
my-app:
  enabled: true
  values:
    - ../../values/defaults/platform/my-app/values.yaml
    - ../../values/defaults/tiers/production.yaml
    - ../../values/prod-cluster/platform/my-app/values.yaml
```

#### 3. External chart with layered overrides

When consuming a Helm chart from a remote repository via the `chart` field, base configuration can be separated from environment-sensitive settings:

```yaml
external-tool:
  enabled: true
  chart: some-chart
  repoURL: https://charts.example.com
  values:
    - ../../values/defaults/platform/external-tool/base.yaml
    - ../../values/defaults/platform/external-tool/monitoring.yaml
    - ../../values/my-cluster/platform/external-tool/values.yaml
```

## Consequences

- The `values` field has a single, consistent format (always a list). No type-detection logic is needed in the template.
- If someone accidentally passes a string instead of a list, Helm will produce an obviously broken result, making the mistake easy to catch.
- When using `values`, the author has full control over file ordering and must explicitly include any cluster-specific files (the automatic defaults + cluster convention does not apply).
- The standard `valuesFolder` and default path mechanisms remain the recommended approach for most components; `values` is for cases that don't fit those patterns.
