# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

kuberise.io is a free, open-source internal developer platform for Kubernetes. It bootstraps a production-ready platform on any cluster using GitOps (ArgoCD) with the app-of-apps pattern. The codebase is infrastructure-as-code - there is no application code, no package.json, no JavaScript build process. It consists of Helm charts, YAML values, bash scripts, and markdown documentation.

## Key Commands

```bash
# Install the kr CLI
curl -sSL https://kuberise.io/install | sh

# Bootstrap a cluster (namespaces, secrets, CA, ArgoCD; --cilium for CNI)
kr init --context <CONTEXT> --cluster <NAME> --domain <DOMAIN>

# Deploy a layer (app-of-apps)
kr deploy --context <CONTEXT> --repo <REPO_URL> \
  --cluster <NAME> --revision <REVISION> --domain <DOMAIN> [--token <TOKEN>]

# Uninstall
kr uninstall --context <CONTEXT> --cluster <NAME>

# Example: local k3d cluster
kr init --context k3d-dev --cluster dev-app-onprem-one --domain k3d.kuberise.dev
kr deploy --context k3d-dev --cluster dev-app-onprem-one \
  --repo https://github.com/<you>/kuberise.io.git \
  --revision main --domain k3d.kuberise.dev

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
- `app-of-apps/values.yaml` defines all 40+ ArgoCD Applications (the single source of truth for what gets deployed)
- `app-of-apps/templates/ArgocdApplications.yaml` generates ArgoCD Application manifests from those definitions
- `app-of-apps/values.schema.json` validates the application definitions - any new field added to the template must also be added here

### Multi-Source Applications (ADR-0014)
Helm-type apps use two sources: (1) chart source (external repo or local path), (2) values source (git repo with `$values/` prefix). Non-Helm apps (kustomize, raw) use single source.

### Value File Hierarchy
1. **Defaults**: `values/defaults/platform/{component}/values.yaml` - always exist, even if empty
2. **Cluster overrides**: `values/{cluster}/platform/{component}/values.yaml` - only created when needed (missing files silently skipped via `ignoreMissingValueFiles: true`)

Values are passed directly to upstream charts (no subchart nesting prefix).

### Operator + Config Chart Pattern
Components needing custom CRD instances are split into two apps: operator app (syncWave 1) installs the upstream chart, config app (syncWave 2) in `charts/{name}-config/` installs CRD instances. Examples: `cert-manager` + `cert-manager-config`, `keycloak` + `keycloak-config`.

### Multi-Cluster and Multi-Layer Support
All clusters share the same charts and external chart references. Per-cluster config lives in `values/{cluster}/` directories. Per-deploy enabler files are in `app-of-apps/values-{name}.yaml` (named after the `--name` layer identifier, not the cluster).

## Adding Components

### New External Component
1. Add to `app-of-apps/values.yaml` under `ArgocdApplications` with `chart`, `repoURL`, `targetRevision` (set `enabled: false`)
2. Create default values in `values/defaults/platform/{name}/values.yaml` (even if empty)
3. Enable in relevant `app-of-apps/values-{name}.yaml` (e.g. `values-webshop.yaml`)
4. Only create cluster-specific values files if actual overrides exist

### New Local Chart
1. Create chart in `charts/{name}/`
2. Add default values in `values/defaults/platform/{name}/values.yaml`
3. Add to `app-of-apps/values.yaml` (no chart/repoURL/targetRevision needed; defaults to `charts/{name}` path)

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
