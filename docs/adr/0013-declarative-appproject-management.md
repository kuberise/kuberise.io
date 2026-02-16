# ADR-0013: Declarative AppProject Management

## Status

Superseded by ADR-0023

## Context

The ArgoCD AppProject resource was created imperatively in `scripts/install.sh` using an inline `kubectl apply` with a heredoc manifest. The same AppProject was not managed by ArgoCD itself, meaning:

1. **No drift detection** -- If someone modified the project through the ArgoCD UI or CLI, ArgoCD would not revert the change.
2. **Duplicate definition risk** -- The AppProject spec lived only in the install script, separate from the Helm chart that manages all other ArgoCD resources. Any future change to the project would require editing the bash script rather than the declarative chart.

However, there is a bootstrapping constraint: the AppProject must exist **before** the app-of-apps Application can be created, because every Application references `project: {{ .Values.global.clusterName }}`. This creates a chicken-and-egg problem if the AppProject is only defined inside the app-of-apps chart.

## Decision

We define the AppProject as a Helm template inside the app-of-apps chart (`app-of-apps/templates/AppProject.yaml`) and use `helm template --show-only` in the install script to render and apply it before creating the app-of-apps Application.

The install script now runs:

```bash
helm template "app-of-apps-$cluster_name" ./app-of-apps \
  --set global.clusterName="$cluster_name" \
  --show-only templates/AppProject.yaml | \
  kubectl apply --context "$context" -n "$namespace" -f -
```

This solves the bootstrapping problem while keeping the AppProject defined in exactly one place:

1. **Bootstrap time**: The install script renders the AppProject template from the chart and applies it via `kubectl apply`. Then it creates the app-of-apps Application as before.
2. **Steady state**: When ArgoCD syncs the app-of-apps chart, it renders the same AppProject template, detects the existing resource, and adopts it. From that point on, `selfHeal: true` ensures any manual drift is reverted.

### Why only the AppProject and not the app-of-apps Application

The same `helm template --show-only` approach could be applied to the root app-of-apps Application itself, turning it into a self-managing resource. We deliberately chose **not** to do this:

- If ArgoCD manages its own root Application, a bad Git commit that breaks the app-of-apps spec would be applied automatically, potentially making the entire platform unrecoverable without manual intervention.
- Keeping the root app-of-apps Application as a manually-managed bootstrap resource (defined only in `install.sh`) acts as a safety guardrail. It can only be changed by re-running the install script, not by a Git push.
- The AppProject does not carry this risk -- a misconfigured project can be corrected by re-running the install script or editing the chart, and it does not affect ArgoCD's ability to sync.

### Alternatives considered

- **Keep the imperative definition in `install.sh` and add a duplicate in the chart**: This works but requires maintaining two copies of the same manifest. Any change to the AppProject spec must be applied in both places, which is error-prone.
- **Only define the AppProject in the chart, skip the bootstrap apply**: This does not work because the app-of-apps Application cannot be created without the project already existing.
- **Apply the same pattern to the app-of-apps Application**: Rejected because making the root Application self-managing removes the safety guardrail against bad Git commits breaking the entire platform (see above).

## Consequences

- The AppProject is defined in a single place (`app-of-apps/templates/AppProject.yaml`), eliminating duplication.
- The install script depends on `helm` being available locally (it was already a prerequisite for the project).
- ArgoCD manages the AppProject declaratively after the initial bootstrap, reverting any manual drift.
- Changes to the AppProject spec are made in the Helm template and take effect both for new installations (via `install.sh`) and existing clusters (via ArgoCD sync).
- The root app-of-apps Application remains a manually-managed bootstrap resource, providing a safety guardrail against self-inflicted misconfiguration.
