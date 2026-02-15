# ADR-0022: Separate manifests/ Directory for Raw and Kustomize Resources

## Status

Rejected

## Context

The `values/` directory currently holds both Helm values files and raw Kubernetes manifests. Raw-type ArgoCD applications (database, policy, secrets, object-storage, raw) point to paths like `values/{cluster}/platform/database/` which contain plain YAML manifests, not Helm values. This was already noted as a naming mismatch in ADR-0020.

It was suggested to create a separate top-level `manifests/` directory for raw and kustomize resources, leaving `charts/` for Helm charts only:

```
├── charts/
│   ├── keycloak/
│   ├── cert-manager/
│   └── generic-deployment/
│
└── manifests/
    ├── databases/
    ├── policies/
    └── secrets/
```

## Decision

Keep raw manifests inside `values/{cluster}/platform/`.

### Reasons

1. **Raw manifests are cluster-specific, not shared.** Each cluster has its own database clusters, Kyverno policies, and Vault secrets. A top-level `manifests/` directory would imply a single shared set, but in practice you would need `manifests/{cluster}/databases/` - recreating the same per-cluster structure that already exists under `values/`.

2. **Splitting breaks the "everything per-cluster lives together" principle.** Today, all cluster-specific configuration - whether Helm values or raw manifests - lives under `values/{cluster}/`. Splitting raw manifests into a separate tree means looking in two places to understand what a cluster deploys.

3. **The ArgoCD multi-source ref would need duplication.** The ArgoCD template currently uses a single `ref: values` source for cluster-specific files. A separate `manifests/` directory would require either a second ref source or restructuring the template logic for raw-type apps.

4. **The naming mismatch is minor.** As ADR-0020 concluded, raw-type apps are the exception, not the rule. The trade-off of a slightly inaccurate directory name is preferable to the complexity of maintaining two parallel per-cluster directory trees.

## Consequences

- Raw manifests remain under `values/{cluster}/platform/`, keeping all per-cluster configuration in one place.
- The naming mismatch between "values" and "raw manifests" persists as an accepted trade-off.
