# ADR-0004: Separate ServerSideApply Control from Additive syncOptions

## Status

Accepted

## Context

The ArgoCD Application template previously treated `syncOptions` as a full replacement for the default `ServerSideApply=true`. If a component provided any custom sync options, `ServerSideApply=true` was dropped entirely. This meant adding an extra sync option (e.g., `PruneLast=true`) while keeping SSA required redundantly including `ServerSideApply=true` in the list. The intent of a custom `syncOptions` list was also ambiguous -- it was unclear whether the goal was to disable SSA or to add unrelated options.

## Decision

We separate ServerSideApply into its own dedicated boolean and make `syncOptions` purely additive.

- **`serverSideApply`**: A per-app boolean (defaults to `true`) controlling the `ServerSideApply` sync option. Uses `hasKey` to correctly handle `false` values (same pattern as ADR-0001's `automated` override).
- **`syncOptions`**: A list of additional sync options that are always appended alongside the defaults (`CreateNamespace=true` and `ServerSideApply`). It no longer replaces anything.

## Consequences

- Disabling SSA is now explicit and self-documenting: `serverSideApply: false`.
- Additional sync options can be added per-app without affecting SSA.
- The two concerns (SSA control vs. extra options) are cleanly separated.
