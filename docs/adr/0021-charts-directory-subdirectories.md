# ADR-0021: Organize charts/ into Subdirectories by Purpose

## Status

Rejected

## Context

The `charts/` directory contains local Helm charts that serve different purposes:

- **Config charts** tightly coupled to operators (`cert-manager-config`, `keycloak-config`, `metallb-config`, `pgadmin-config`, `k8sgpt-config`)
- **A CRD chart** (`kube-prometheus-stack-crds`)
- **Infrastructure charts** (`ingresses`, `teams-namespaces`, `team-setup`, `secrets-manager`)
- **An example app** (`hello`)
- **A reusable generic chart** (`generic-deployment`)
- **Platform components** (`backstage`, `dashboards`, `tekton-operator`)

It was suggested to split these into subdirectories such as `charts/config/`, `charts/platform/`, `charts/examples/` to separate concerns.

## Decision

Keep the flat `charts/` directory structure.

### Reasons

1. **The directory is small enough.** With ~15 charts, a flat listing is easy to scan. Subdirectories add value at 30+ items, not at the current size.

2. **Naming conventions already communicate purpose.** The `*-config` suffix clearly identifies operator config charts. No subdirectory is needed to convey what these charts are.

3. **It would break ArgoCD path references.** The `ArgocdApplications.yaml` template builds chart paths as `charts/{name}`. Moving charts into subdirectories would require updating the path logic, every app-of-apps entry for local charts, and the values schema - real churn for a cosmetic benefit.

4. **Category boundaries are subjective.** Charts like `secrets-manager` or `team-setup` do not fit cleanly into a single category. A flat structure avoids debates about where each chart belongs.

5. **Premature organization.** The suggestion acknowledged this with "if the project grows." The reorganization cost is not justified at the current scale and can be revisited if the directory doubles in size.

## Consequences

- The `charts/` directory remains flat and all ArgoCD references stay unchanged.
- If the number of local charts grows significantly, this decision should be revisited.
