# ADR-0012: Independent Configuration of prune and selfHeal

## Status

Proposed

## Context

When automated sync is enabled for an ArgoCD Application (via `global.automated` or per-app `automated: true`), the app-of-apps template currently hard-codes both `prune: true` and `selfHeal: true` together:

```yaml
automated:
  prune: true
  selfHeal: true
  allowEmpty: false
```

This means there is no way to enable automated sync with only one of the two flags. Some teams have a legitimate need to run `selfHeal: true` but `prune: false` -- they want ArgoCD to revert manual drift on existing resources, but they do not want ArgoCD to automatically delete resources that are removed from Git. This protects against accidental resource deletion caused by bad merges, accidental value file changes, or template rendering errors that drop resources.

Conversely, some teams may want `prune: true` but `selfHeal: false` -- for example, when operators or controllers legitimately modify resources at runtime and those changes should not be reverted.

## Decision

We acknowledge this as a valid future enhancement but choose **not** to implement it now for the following reasons:

1. **Current simplicity** -- The existing template treats automated sync as a single toggle. This keeps the template simple and the mental model clear: automated sync is either fully on or fully off.

2. **No current demand** -- No cluster or team in the project currently requires independent control of `prune` and `selfHeal`. Adding configuration surface area without a concrete use case risks premature complexity.

3. **Easy to implement when needed** -- The change is small and backward-compatible. When the need arises, the template can be updated to:

```yaml
automated:
  prune: {{ hasKey $app "prune" | ternary $app.prune true }}
  selfHeal: {{ hasKey $app "selfHeal" | ternary $app.selfHeal true }}
  allowEmpty: false
```

This would allow per-app overrides such as:

```yaml
my-application:
  enabled: true
  prune: false       # disable prune while keeping selfHeal
```

The defaults remain `true` for both, so existing application definitions continue to work unchanged.

4. **Schema update required** -- When implemented, `prune` and `selfHeal` boolean properties must be added to `app-of-apps/values.schema.json` under `definitions.argocdApplication.properties` (see ADR-0009).

## Consequences

- The current behavior is preserved: when automated sync is enabled, both `prune` and `selfHeal` are always `true`.
- This ADR serves as a reference for the future implementation when independent control is needed.
- When implementing, the change is backward-compatible -- no existing values files need modification since both fields default to `true`.
- Teams that need independent control in the meantime can set `automated: false` and manage sync policy manually in ArgoCD.
