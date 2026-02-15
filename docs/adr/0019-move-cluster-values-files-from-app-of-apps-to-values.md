# ADR-0019: Move Cluster Values Files from app-of-apps/ to values/{cluster}/

## Status

Rejected

## Context

The platform's cluster-specific configuration currently lives in two places:

1. **`app-of-apps/values-{cluster}.yaml`** - which applications are enabled or disabled for a given cluster
2. **`values/{cluster}/platform/`** - the Helm values that configure each component on that cluster

To understand "what is deployed on AKS and how," an operator must look in both `app-of-apps/values-aks.yaml` and `values/aks/platform/`.

A unified `clusters/` directory was proposed that would consolidate all cluster-specific configuration in one place:

```
clusters/
  aks/
    app-of-apps.yaml        # currently app-of-apps/values-aks.yaml
    platform/                # currently values/aks/platform/
    applications/            # currently values/aks/applications/
  eks/
    app-of-apps.yaml
    platform/
    applications/
```

This would let an operator find everything about a cluster in a single directory tree.

## Decision

Rejected. Keep `app-of-apps/values-{cluster}.yaml` inside the `app-of-apps/` chart directory.

### Reasons

1. **`app-of-apps/` is a standard Helm chart.** Having `values-*.yaml` files alongside `Chart.yaml` and `templates/` is idiomatic Helm. Moving the values files outside the chart directory breaks this convention and makes the chart less self-contained.

2. **ArgoCD source path coupling.** The root ArgoCD Application references the app-of-apps chart with `path: ./app-of-apps` and loads values via `valueFiles: [values-{cluster}.yaml]` (a path relative to the chart root). Moving the file to `clusters/{cluster}/app-of-apps.yaml` would require a relative path like `../../clusters/{cluster}/app-of-apps.yaml`, which is fragile and harder to reason about.

3. **Separation of concerns.** The two directories answer different questions:
   - `app-of-apps/values-{cluster}.yaml`: *which* applications are deployed (enable/disable toggles)
   - `values/{cluster}/platform/`: *how* each application is configured (Helm values)

   These are distinct concerns. The app-of-apps values file is part of the Helm chart that generates ArgoCD Application manifests. The values directory is the data layer consumed by those generated Applications at sync time. Keeping them separate reflects this architectural boundary.

4. **Moderate benefit.** The convenience of a single directory per cluster is real but moderate - operators rarely need to see both views simultaneously.

## Consequences

- Operators must look in two places to get the full picture of a cluster's configuration.
- The `values/defaults/` directory remains the baseline, with cluster-specific overrides in `values/{cluster}/`, consistent with the pattern described in ADR-0002.
- The app-of-apps chart remains a self-contained, idiomatic Helm chart.
