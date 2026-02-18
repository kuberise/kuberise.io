# ADR-0023: Single AppProject Per Cluster

## Status

Accepted (supersedes ADR-0013)

## Context

ArgoCD AppProjects group Applications and define access controls (allowed source repos, destination namespaces, cluster resource whitelists). With multi-layer deployment, a single cluster can host multiple app-of-apps Applications (e.g., `app-of-apps-platform`, `app-of-apps-webshop`), each deploying a different set of tools. This raises the question of how many AppProjects to create per cluster:

1. **One project per layer** - each `kr deploy` creates its own AppProject (e.g., `platform`, `webshop`).
2. **One project per cluster** - all layers share a single AppProject.

Additionally, ADR-0013 placed the AppProject inside the app-of-apps Helm chart so ArgoCD could manage it declaratively. In practice this created a circular dependency during deletion: the app-of-apps Application tried to delete the AppProject, but the AppProject's `resources-finalizer` blocked deletion because the app-of-apps still belonged to it.

## Decision

### One AppProject per cluster, named `kuberise`

All layers share a single AppProject named `kuberise`. The `kr deploy` command creates it inline via `kubectl apply` before creating the app-of-apps Application.

The project name is passed to child applications via `global.argoProject` (default: `kuberise`), keeping the template flexible if multiple projects are needed in the future.

### AppProject created outside the Helm chart

The AppProject is no longer a Helm template inside the app-of-apps chart. Instead, `kr deploy` creates it directly with `kubectl apply`. This breaks the circular dependency that ADR-0013's approach caused during uninstall.

### Why one project is enough

- **Each cluster has its own ArgoCD instance.** Cross-cluster isolation is already handled at the infrastructure level. A per-layer AppProject does not add meaningful isolation beyond what already exists.
- **The AppProject allows everything.** The current spec uses `'*'` for sourceRepos, destinations, and clusterResourceWhitelist. Multiple projects with identical permissive specs add management overhead with no security benefit.
- **Simpler mental model.** One project means `kr deploy` is idempotent on the AppProject - the first deploy creates it, subsequent deploys see it already exists. No need to coordinate project names across layers.

### When to revisit

If kuberise introduces per-layer RBAC (e.g., restricting the client layer to only deploy to certain namespaces, or restricting source repos per layer), splitting into multiple projects would make sense. The `global.argoProject` parameter is already in place to support this without changing the template.

## Consequences

### Positive

- No circular dependency during uninstall. The AppProject is deleted by `kr uninstall` after all Applications are gone.
- Single project is simple to reason about and manage.
- The `global.argoProject` parameter keeps the template flexible for future multi-project setups.
- `kr deploy` is idempotent - safe to run multiple times for different layers.

### Negative

- No per-layer access control. All layers can deploy to any namespace and use any source repo. This is acceptable for now since the AppProject is fully permissive anyway.
- The AppProject is not managed by ArgoCD (no drift detection). This is a minor trade-off; the AppProject spec rarely changes, and `kr deploy` re-applies it on every run.
- ADR-0013's goal of declarative AppProject management via GitOps is abandoned in favor of the simpler imperative approach.
