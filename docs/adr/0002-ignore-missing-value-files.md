# ADR-0002: Enable ignoreMissingValueFiles and Remove Empty Cluster Value Files

## Status

Accepted

## Context

The ArgoCD app-of-apps template (`app-of-apps/templates/ArgocdApplications.yaml`) generates Helm-type ArgoCD Applications with a two-level value file hierarchy:

1. **Default values**: `values/defaults/platform/{component}/values.yaml`
2. **Cluster-specific overrides**: `values/{cluster}/platform/{component}/values.yaml`

Previously, both files were required to exist for every component in every cluster, even when no cluster-specific overrides were needed. This led to a large number of empty placeholder files (138 across 6 clusters) that served no functional purpose.

We needed to decide between two approaches:

- **Explicit placeholders**: Require empty value files in every cluster directory so the file tree shows all available components. This makes it clear where to add overrides, but creates significant maintenance burden.
- **Ignore missing files**: Enable ArgoCD's `ignoreMissingValueFiles` and only create cluster-specific files when actual overrides are needed. The defaults directory serves as the canonical reference for available components.

## Decision

### 1. Enable ignoreMissingValueFiles in the ArgoCD Application template

We set `ignoreMissingValueFiles: true` in the Helm section of the generated ArgoCD Applications. This tells ArgoCD to silently skip value files that don't exist rather than failing the sync.

### 2. Keep default value files as required placeholders

Files in `values/defaults/platform/{component}/values.yaml` must always exist, even if empty. These serve as:

- The canonical list of all available platform components
- Sensible defaults that apply to all clusters
- A discoverability aid for contributors browsing the defaults directory

### 3. Only create cluster-specific value files when needed

Files in `values/{cluster}/platform/{component}/values.yaml` should only be created when there are actual configuration overrides for that specific cluster. Empty placeholder files in cluster directories are no longer needed and should not be created.

### Why this middle-ground approach

| Concern | How it's addressed |
|---|---|
| Discoverability of available components | Browse `values/defaults/platform/` to see all components |
| Where to put cluster overrides | Path convention is documented: `values/{cluster}/platform/{component}/values.yaml` |
| New component onboarding | Only need to create default values file, not files in every cluster |
| New cluster onboarding | Only need cluster-specific overrides, not empty files for all components |
| Maintenance burden | Reduced from ~40 files per cluster to only files with actual content |

### Why not keep explicit placeholders everywhere

- With 6 clusters and ~40 components, the project had 138 empty files that carried no information beyond what the defaults directory already showed.
- Every new component required creating an empty file in every cluster directory.
- Every new cluster required creating empty files for every component.
- The convention for the correct file path (`values/{cluster}/platform/{component}/values.yaml`) is documented and enforced by the template, making the empty files redundant as documentation.

## Consequences

- ArgoCD Applications gracefully handle missing cluster-specific value files, falling back to defaults only.
- The `values/defaults/` directory remains the single source of truth for available components.
- Cluster value directories are leaner, containing only files with actual overrides, making it easier to see at a glance what is customized per cluster.
- Contributors must check `values/defaults/platform/` (not their cluster directory) to discover available components.
- Adding a new component no longer requires touching every cluster directory.
- Adding a new cluster no longer requires copying empty files for every component.
