# ADR-0007: Add Bounded Retry with Exponential Backoff to Sync Policy

## Status

Accepted

## Context

ADR-0001 introduced `retry.refresh: true` so that sync retries re-fetch the latest Git revision. However, the retry policy had no `limit` or `backoff` configuration, meaning ArgoCD used its default unbounded retry behavior. This could lead to:

- Indefinite retry loops for genuinely broken configurations, delaying detection
- Rapid-fire retries putting unnecessary load on the API server, especially during initial installation when many applications fail concurrently waiting for CRDs or dependencies

## Decision

We add a bounded retry with exponential backoff to the sync policy:

```yaml
retry:
  refresh: true
  limit: 5
  backoff:
    duration: 10s
    factor: 2
    maxDuration: 3m
```

- **`limit: 5`**: Retry up to 5 times before giving up. Enough to ride out transient failures (CRD ordering, temporary API server errors) while failing fast enough to surface real issues in alerts.
- **`duration: 10s`**: Initial wait of 10 seconds before the first retry. The 10-second starting point (rather than 5s) gives the cluster breathing room when many apps are syncing simultaneously during installation.
- **`factor: 2`**: Standard exponential backoff -- each retry doubles the wait time (10s, 20s, 40s, 80s, 160s).
- **`maxDuration: 3m`**: Caps wait time at 3 minutes so no single retry interval becomes excessively long.

The total retry window is approximately 5 minutes, after which the application surfaces as failed for operator attention.

## Consequences

- Transient failures (CRD not yet available, temporary API server errors, dependency ordering) are handled automatically within the retry window.
- Genuinely broken configurations fail within ~5 minutes instead of retrying indefinitely, enabling faster detection and alerting.
- API server load is reduced during concurrent sync operations by spacing retries exponentially.
- `refresh: true` (from ADR-0001) continues to ensure each retry picks up the latest Git revision.
