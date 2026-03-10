# ADR-0007: Add Retry with Exponential Backoff to Sync Policy

## Status

Accepted (updated)

## Context

ADR-0001 introduced `retry.refresh: true` so that sync retries re-fetch the latest Git revision. However, the retry policy had no `limit` or `backoff` configuration, meaning ArgoCD used its default unbounded retry behavior. This could lead to rapid-fire retries putting unnecessary load on the API server, especially during initial installation when many applications fail concurrently waiting for CRDs or dependencies.

An earlier version used `limit: 5` (bounded retries) to surface broken configurations quickly. In practice, this caused problems: applications in earlier sync waves would exhaust their retry budget before dependencies (secrets, CRDs, operators) were ready, blocking all subsequent sync waves permanently. This required manual intervention to restart syncing.

## Decision

We use unlimited retries with exponential backoff:

```yaml
retry:
  refresh: true
  limit: 0
  backoff:
    duration: 10s
    factor: 2
    maxDuration: 3m
```

- **`limit: 0`**: Unlimited retries. Applications in earlier sync waves must keep retrying so that later waves can eventually proceed once dependencies are available. This is critical for the CAPI operator flow where secrets and CRDs may take minutes to become available.
- **`duration: 10s`**: Initial wait of 10 seconds before the first retry. Gives the cluster breathing room when many apps are syncing simultaneously during installation.
- **`factor: 2`**: Standard exponential backoff (10s, 20s, 40s, 80s, 160s, then capped).
- **`maxDuration: 3m`**: Caps wait time at 3 minutes, ensuring retries happen at least every 3 minutes.

## Consequences

- Transient failures (CRD not yet available, secrets pending creation, dependency ordering) are handled automatically without manual intervention.
- Sync waves work correctly: earlier waves keep retrying until dependencies are ready, allowing later waves to proceed.
- API server load is controlled by exponential backoff with a 3-minute cap.
- `refresh: true` (from ADR-0001) continues to ensure each retry picks up the latest Git revision.
- Genuinely broken configurations will retry indefinitely. Operators should monitor ArgoCD for applications stuck in a failed state rather than relying on retry exhaustion.
