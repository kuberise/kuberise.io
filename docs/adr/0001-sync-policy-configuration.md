# ADR-0001: ArgoCD Sync Policy Configuration

## Status

Accepted

## Context

We use ArgoCD's app-of-apps pattern to manage all platform and application deployments. Every ArgoCD Application is generated from a shared Helm template (`app-of-apps/templates/ArgocdApplications.yaml`), so sync policy decisions apply broadly across all managed applications.

We need to define a clear and safe automated sync policy that:

- Enables GitOps-driven deployments without manual intervention
- Protects against accidental or catastrophic resource deletion
- Allows per-application override of auto-sync behavior
- Keeps the template readable and explicit about its choices

Key ArgoCD sync policy options we evaluated:

- `automated.prune` -- automatically delete resources no longer in Git
- `automated.selfHeal` -- revert manual cluster changes to match Git
- `automated.allowEmpty` -- allow pruning even when it would result in zero resources
- `automated.enabled` -- explicitly enable/disable auto-sync
- `retry.refresh` -- re-fetch latest Git revision on sync retries

## Decision

### 1. Enable automated sync with prune and selfHeal

All applications use `automated` sync with `prune: true` and `selfHeal: true` by default, controlled by `global.automated` in the values file.

### 2. Rely on allowEmpty defaulting to false

We rely on ArgoCD's default `allowEmpty: false` to prevent pruning all resources if a Helm chart accidentally renders zero manifests.

#### Why allowEmpty: false

When `prune: true` is enabled, ArgoCD deletes cluster resources that are no longer defined in Git. The `allowEmpty` flag controls what happens when **all** resources disappear from Git -- meaning the application would end up completely empty.

With `allowEmpty: false`, ArgoCD refuses to prune in this case, acting as a safety net against accidental full deletion. With `allowEmpty: true`, ArgoCD proceeds and deletes everything.

| Scenario | allowEmpty: false | allowEmpty: true |
|---|---|---|
| Someone accidentally empties a values file | Sync blocked, no damage | All resources deleted |
| Git repo corruption / bad merge | Sync blocked, no damage | All resources deleted |
| Intentionally removing all resources | Requires manual sync | Works automatically |

The only downside is that intentionally emptying an application requires a manual sync, which is a rare operation and an acceptable trade-off for the safety it provides.

#### Why we do NOT set allowEmpty: false explicitly

We originally set `allowEmpty: false` explicitly in the template for readability. However, the ArgoCD Application CRD defines the `allowEmpty` field with Go's `omitempty` JSON tag. For booleans, `omitempty` causes the JSON serializer to strip the field when its value is `false` (the zero value). This creates a permanent OutOfSync loop:

1. The template renders `allowEmpty: false` in the desired manifest.
2. ArgoCD applies it to the API server.
3. The API server serializes the object back without `allowEmpty` (stripped by `omitempty`).
4. ArgoCD reads the live manifest, sees no `allowEmpty` field, compares it to the desired `allowEmpty: false`, and detects a diff.
5. The application stays OutOfSync forever.

Since `false` is already the default, omitting the field changes nothing in behavior. A YAML comment in the template documents the intent instead.

### 3. Do not use automated.enabled field

ArgoCD supports a `spec.syncPolicy.automated.enabled` field to toggle auto-sync on/off without removing the `automated` block. We chose not to use it because:

- We already control auto-sync via a boolean toggle (`global.automated` / per-app `automated`) that conditionally renders the entire `automated:` block.
- Using `enabled` would still require the same `hasKey` logic to resolve the value correctly, so it does not simplify the template.
- It adds a dependency on a newer ArgoCD feature for no practical benefit.

### 4. Use hasKey instead of Helm's default for boolean overrides

Per-application override of the `automated` flag uses `hasKey` instead of Helm's `default` function:

```yaml
{{- $automated := $.Values.global.automated }}
{{- if hasKey . "automated" }}
  {{- $automated = .automated }}
{{- end }}
```

This is necessary because Helm's `default` function treats `false` as "empty" and falls through to the fallback value. If a per-app `automated: false` were evaluated with `default`, Helm would ignore it and use the global value instead -- the opposite of the intended behavior. `hasKey` checks for key existence regardless of value, handling `false` correctly.

### 5. Enable retry.refresh

We enable `retry.refresh: true` so that when a sync fails and ArgoCD retries, it re-fetches the latest Git revision first. This prevents wasting retry attempts on a stale revision when a fix has already been pushed.

## Consequences

- Applications auto-sync and self-heal by default, enabling fully GitOps-driven deployments.
- Per-application override is possible by setting `automated: false` in the application's values.
- Empty application state is protected against accidental pruning via `allowEmpty` defaulting to `false`.
- Sync retries pick up the latest Git state, reducing recovery time after pushing fixes.
- The template documents all sync policy decisions via explicit values and comments.
