# ADR-0020: Rename values/ Directory to config/

## Status

Rejected

## Context

The `values/` directory contains per-cluster and default configuration for all platform components. Most of its contents are Helm values files (`values.yaml`), but it also holds raw Kubernetes manifests for apps of type `raw` (e.g., `values/{cluster}/platform/database/`, `values/{cluster}/platform/policy/`, `values/{cluster}/platform/raw/`). Since these raw manifests are not Helm values, the directory name `values/` does not accurately describe all of its contents.

Renaming to `config/` was considered as a more general and accurate name.

## Decision

Keep the directory named `values/`.

### Reasons

1. **Helm convention.** `values/` is immediately recognizable to anyone familiar with Helm. `config/` is generic and does not convey what kind of configuration it contains.

2. **The contents are overwhelmingly Helm values files.** Raw Kubernetes manifests are the exception, not the rule. The directory name should reflect the primary use case.

3. **Pairs with the ArgoCD multi-source ref name.** The ArgoCD template uses a `ref: values` source and references files as `$values/values/defaults/...`. The directory name and the ref name reinforce each other.

4. **`config/` invites scope creep.** A directory called `config/` could attract unrelated configuration (CI config, script config, editor config). `values/` has a clear, narrow scope.

## Consequences

- Raw-type applications store Kubernetes manifests inside `values/{cluster}/platform/`, which is a naming mismatch. This is an acceptable trade-off given the small number of raw-type apps.
