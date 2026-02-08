# ADR-0010: Kustomize Parameters Support in ArgoCD Application Template

## Status

Deferred

## Context

The `app-of-apps/templates/ArgocdApplications.yaml` template supports three application types: `helm`, `kustomize`, and `raw`. For kustomize-type applications, the template currently only sets `source.path` and optionally `source.directory.recurse`. There is no support for kustomize-specific features that ArgoCD provides, such as:

- `kustomize.namePrefix`
- `kustomize.nameSuffix`
- `kustomize.images`
- `kustomize.commonLabels`
- `kustomize.commonAnnotations`

If any kustomize application needs these features, there is currently no way to configure them through the values files.

## Decision

This enhancement is deferred. The current kustomize applications in the platform (e.g., `dashboards`) do not require these parameters, and adding support would increase template complexity and require corresponding updates to `values.schema.json` (see ADR-0009).

When a concrete need arises for kustomize parameters, the implementation should:

1. Add optional kustomize fields (e.g., `namePrefix`, `nameSuffix`, `images`, `commonLabels`, `commonAnnotations`) to the application definition in `app-of-apps/values.yaml`.
2. Update `app-of-apps/templates/ArgocdApplications.yaml` to render these fields under `source.kustomize` when the application type is `kustomize`.
3. Update `app-of-apps/values.schema.json` to include the new properties with appropriate type constraints.

## Consequences

- Kustomize-type applications that need parameters like `namePrefix`, `images`, or `commonLabels` cannot be configured through values files until this is implemented.
- Workaround: such applications can be defined directly as raw ArgoCD Application manifests in `templates/` instead of going through the app-of-apps template.
- No impact on existing applications, as none currently require these kustomize features.
