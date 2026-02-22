---
name: add-local-chart
description: Scaffold a new local Helm chart and register it in the app-of-apps
---

# Add Local Chart

Scaffold a new local Helm chart for a component that doesn't have an external chart repository.

## 1. Gather information

Ask the user for:
- Chart name (kebab-case, e.g., `my-dashboard`)
- Brief description of what it does
- Target namespace (defaults to chart name)
- Whether it needs a companion `-config` chart (operator + config pattern)
- Application type: `helm` (default), `kustomize`, or `raw`

## 2. Create chart structure

For Helm type, create in `charts/{chart-name}/`:

```
charts/{chart-name}/
  Chart.yaml
  values.yaml
  templates/
    _helpers.tpl
    (resource templates)
```

Chart.yaml should follow:
```yaml
apiVersion: v2
name: {chart-name}
description: {description}
type: application
version: 0.1.0
appVersion: "0.1.0"
```

For kustomize type, create in `charts/{chart-name}/`:
```
charts/{chart-name}/
  kustomization.yaml
  (resource files)
```

## 3. Create default values file

Create `values/defaults/platform/{chart-name}/values.yaml` (even if empty).

## 4. Register in app-of-apps/values-base.yaml

Add under `ArgocdApplications`. Local charts don't need `chart`, `repoURL`, or `targetRevision` fields - they default to `charts/{name}` path.

```yaml
  {chart-name}:
    enabled: false
```

Add `type: kustomize` or `type: raw` if not Helm. Add `namespace` only if it differs from the chart name.

## 5. Enable in cluster values

Add to the relevant `app-of-apps/values-{name}.yaml` enabler file (e.g. `values-webshop.yaml`) with `enabled: true`.

## Conventions

- Use 2-space YAML indentation
- Chart names are kebab-case
- Use `_helpers.tpl` for reusable template functions
- Include `global.domain` and `global.clusterName` parameters where relevant
