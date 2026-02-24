# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

kuberise.io is a free, open-source internal developer platform for Kubernetes. It bootstraps a production-ready platform on any cluster using GitOps (ArgoCD) with the app-of-apps pattern. The codebase is infrastructure-as-code - there is no application code, no package.json, no JavaScript build process. It consists of Helm charts, YAML values, bash scripts, and markdown documentation.

## Key Commands

```bash
# Install the kr CLI
curl -sSL https://kuberise.io/install | sh

# Primary command: init-if-needed + deploy all clusters (run from client repo root)
kr up --repo https://github.com/<you>/client-webshop.git

# Teardown all clusters
kr down --repo https://github.com/<you>/client-webshop.git

# Escape hatches for fine-grained control:
kr init                                    # Init all clusters from kuberise.yaml
kr init --cluster mgmt                     # Init only one cluster
kr init --context k3d-dev --domain k3d.kuberise.dev  # Legacy mode (no kuberise.yaml)
kr deploy --repo <CLIENT_REPO_URL>         # Deploy only (skip init)
kr uninstall --context <CONTEXT> --cluster <NAME>

# Check for newer versions of external Helm charts
./scripts/upgrade.sh

# Local multi-cluster dev setup (creates k3d-shared and k3d-dev clusters)
./scripts/k3d+registry/start.sh

# Delete local clusters
./scripts/k3d+registry/delete-all.sh
```

There are no unit tests or linters. Testing is done by deploying to a development Kubernetes cluster and verifying ArgoCD sync status.

## Architecture

### App-of-Apps Pattern
- `app-of-apps/` is the centralized Helm chart shared by all layers (OSS, pro, client)
- `app-of-apps/values-base.yaml` defines all 40+ platform applications (all disabled by default)
- `app-of-apps/templates/ArgocdApplications.yaml` generates ArgoCD Application manifests from values
- `app-of-apps/values.schema.json` validates the application definitions - any new field added to the template must also be added here
- Pro/client repos provide only value overlays (`app-of-apps/values-base.yaml`) - no templates or Chart.yaml
- Client repos have `kuberise.yaml` at their root with a `clusters:` map declaring all clusters, their contexts, domains, and layers
- `kr up` is the primary command - it reads `kuberise.yaml`, bootstraps clusters that need init (detects via `helm status argocd`), and deploys all layers in parallel
- `kr init` and `kr deploy` are escape hatches for fine-grained control; `kr init` also reads `kuberise.yaml` when available

### Multi-Source Applications (ADR-0014)
Helm-type apps use two sources: (1) chart source (external repo or local path), (2) values source (git repo with `$values/` prefix). Non-Helm apps (kustomize, raw) use single source. Per-app `repoURL: kuberise` resolves to the OSS repo, letting client-layer apps reference charts from kuberise.io (e.g., `charts/generic-deployment`).

### Value File Hierarchy
1. **Defaults**: `values/defaults/platform/{component}/values.yaml` - always exist, even if empty
2. **Cluster overrides**: `values/{cluster}/platform/{component}/values.yaml` - only created when needed (missing files silently skipped via `ignoreMissingValueFiles: true`)

Values are passed directly to upstream charts (no subchart nesting prefix).

### Operator + Config Chart Pattern
Components needing custom CRD instances are split into two apps: operator app (syncWave 1) installs the upstream chart, config app (syncWave 2) in `charts/{name}-config/` installs CRD instances. Examples: `cert-manager` + `cert-manager-config`, `keycloak` + `keycloak-config`.

### Multi-Cluster and Multi-Layer Support
All clusters share the same charts and external chart references. Per-cluster config lives in `values/{cluster}/` directories. Each client repo has a `kuberise.yaml` with a `clusters:` map - each key is a cluster name with its context, domain, and layers. `kr up` handles init-if-needed + deploy for all clusters in parallel with retry for inaccessible clusters (supports CAPI-created clusters). Smart ArgoCD detection (`helm status argocd`) skips init on already-bootstrapped clusters. Enabler files (`values-{clusterName}-{layerName}.yaml`) in the client repo control which apps each layer deploys per cluster.

## Adding Components

**Important**: All apps in `app-of-apps/values-base.yaml` MUST have `enabled: false`. Each layer's `values-base.yaml` is loaded explicitly (not auto-loaded by Helm), so only that layer's definitions are visible. Enablement is controlled exclusively by the client repo's enabler files.

### New External Component
1. Add to `app-of-apps/values-base.yaml` under `ArgocdApplications` with `chart`, `repoURL`, `targetRevision` (set `enabled: false`)
2. Create default values in `values/defaults/platform/{name}/values.yaml` (even if empty)
3. Enable in the client repo's enabler file (e.g. `client-webshop/app-of-apps/values-dev-platform.yaml`)
4. Only create cluster-specific values files if actual overrides exist

### New Local Chart
1. Create chart in `charts/{name}/`
2. Add default values in `values/defaults/platform/{name}/values.yaml`
3. Add to `app-of-apps/values-base.yaml` with `enabled: false` (no chart/repoURL/targetRevision needed; defaults to `charts/{name}` path)

## Conventions

- **YAML**: 2-space indentation
- **Naming**: kebab-case for components, namespaces, chart directories
- **Cluster names**: `{env}-{type}-{provider}-{region}` (e.g., `prod-app-aws-frankfurt`, `dev-shared-onprem-one`)
- **Domain pattern**: `{service}.{global.domain}`
- **Bash scripts**: use `set -euo pipefail`
- **Writing style**: never use em dash (--), use hyphen (-) or rephrase
- **Defaults**: be explicit about default values in templates rather than relying on implicit defaults
- **Version format**: use `0.3.0` format (no 'v' prefix) everywhere - git tags, release notes, changelogs, docs. Third-party tool versions follow their upstream format
- **Breaking changes**: document in RELEASE_NOTES.md
- **ADRs**: stored in `docs/adr/`, use standard format (Status, Context, Decision, Consequences)

## Releasing a New Version

When adding a new release version to `RELEASE_NOTES.md`, you must also update the website (`https.kuberise.io` repo):
1. **Changelog entry**: Create `https.kuberise.io/content/4.changelog/{N}.{major}-{minor}-{patch}.md` with frontmatter (title, description, date, image) and release notes content. The file number `{N}` should be the next sequential number after the existing entries.
2. **Version badge**: Update the `version` field in `https.kuberise.io/app/app.config.ts` to the new version (e.g., `'0.3.0'`). This version is displayed next to the logo in the website header.

## CI/CD

- GitHub Actions workflow (`.github/workflows/trigger-website.yml`) triggers Cloudflare Pages rebuild when `docs/public/**` changes on main
- ArgoCD handles all platform deployment via GitOps (automated sync with prune + selfHeal)
