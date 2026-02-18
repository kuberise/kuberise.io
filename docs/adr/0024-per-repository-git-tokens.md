# ADR-0024: Per-Repository Git Tokens for Deploy

## Status

Accepted

## Context

The `kr deploy` command supports a split-repo topology (ADR-0014) where charts, default values, and cluster values can each reside in a separate Git repository:

```
--repo               Charts and app-of-apps definitions
--defaults-repo      Default value files
--values-repo        Cluster-specific value overrides
```

However, the command only accepted a single `--token` flag. This token was reused for all three ArgoCD repository secrets. In practice, the three repositories may belong to different Git organizations, different providers, or require different access scopes:

- `--repo` might point to the public `kuberise/kuberise.io` (or internal private repo e.g. airgap environment)
- `--defaults-repo` might point to a private `org/kuberise-pro` repository (org-level token)
- `--values-repo` might point to a client-specific `org/client-webshop` repository (client-scoped token, possibly on a different Git host)

With a single token, users had to work around this by either granting one token access to all repositories (overly broad permissions) or running separate credential setup outside of `kr deploy`.

## Decision

### Add `--values-token` and `--defaults-token` flags

The `kr deploy` command now accepts three token flags, one per repository:

| Flag | Applies to | Default |
|------|-----------|---------|
| `--token` | `--repo` (also fallback for the other two) | (none) |
| `--values-token` | `--values-repo` | Same as `--token` |
| `--defaults-token` | `--defaults-repo` | Same as `--token` |

This mirrors the existing pattern where `--values-repo` and `--defaults-repo` each default to `--repo`.

### Cascade logic

If only `--token` is provided, it is used for all repositories - preserving existing behavior. Individual token flags override the fallback only when explicitly provided:

```bash
# Single token for all repos (existing behavior, unchanged)
kr deploy --repo ... --token $TOKEN

# Different tokens per repo
kr deploy --repo ... --token $PLATFORM_TOKEN \
  --values-repo ... --values-token $CLIENT_TOKEN \
  --defaults-repo ... --defaults-token $PRO_TOKEN

# Public chart repo, private values repo
kr deploy --repo https://github.com/kuberise/kuberise.io.git \
  --values-repo https://github.com/org/client.git --values-token $TOKEN
```

### Secret creation logic

Each ArgoCD repository secret is created independently based on its own token. A secret is created when:

1. The token for that repository is non-empty, AND
2. The repo URL or token differs from an already-created secret (to avoid duplicate secrets for the same credentials)

This means a repository with no token simply gets no secret, which is correct for public repositories.

## Consequences

### Positive

- Supports least-privilege access. Each repository can use a token scoped to only that repository or organization.
- Supports multi-provider setups. The chart repo can be on GitHub while the values repo is on GitLab, each with its own authentication.
- Full backward compatibility. Existing commands with a single `--token` work identically.
- Consistent CLI design. The `--values-token`/`--defaults-token` flags follow the same naming pattern as `--values-repo`/`--defaults-repo` and `--values-revision`/`--defaults-revision`.

### Negative

- More flags to document and remember. The help text grows by two lines. This is mitigated by the cascade default - most users will continue using just `--token`.
