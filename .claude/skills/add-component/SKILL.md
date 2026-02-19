---
name: add-component
description: Walk through adding a new external Helm component to the kuberise platform
---

# Add External Component

Guide the user through adding a new external Helm component to the kuberise.io platform. Follow these steps in order:

## 1. Gather information

Ask the user for:
- Component name (kebab-case, e.g., `harbor`, `crossplane`)
- Helm chart name (e.g., `harbor`, often same as component name)
- Helm repository URL (e.g., `https://helm.goharbor.io`)
- Chart version (e.g., `1.16.0`)
- Target namespace (defaults to component name)
- Which clusters should have it enabled

## 2. Add to app-of-apps/values.yaml

Add the component under `ArgocdApplications` in the appropriate section (Platform Core, Data Services, Network Services, Security & Auth, Monitoring, AI Tools, CI/CD). Set `enabled: false` by default.

Example entry:
```yaml
  component-name:
    enabled: false
    chart: chart-name
    repoURL: https://example-repo.io
    targetRevision: 1.0.0
```

Only add `namespace` if it differs from the component name. Only add fields that differ from defaults.

## 3. Create default values file

Create `values/defaults/platform/{component-name}/values.yaml`. This file must always exist, even if empty. Values should be at the top level (no subchart nesting prefix) since they are passed directly to the upstream chart.

## 4. Enable in cluster values files

Add the component to the relevant `app-of-apps/values-{name}.yaml` enabler file (e.g. `values-webshop.yaml`) with `enabled: true`.

## 5. Operator + Config pattern (if needed)

If the component installs CRDs and needs CRD instances (e.g., certificates, policies, custom resources):
1. The main component entry installs the upstream chart (syncWave 1, default)
2. Create a config chart in `charts/{component-name}-config/` with CRD instances
3. Create a default values file for the config chart too
4. Add a second entry `{component-name}-config` with `syncWave: 2`

## 6. Update website homepage

Remind the user to add the tool's name and logo to the homepage in `https.kuberise.io/content/0.index.yml` under the logos section.

## 7. Verify

- Check that the new entry in `values.yaml` has valid YAML syntax
- Verify the default values file exists at the correct path
- Confirm no schema validation fields are missing (check `app-of-apps/values.schema.json` if new fields were introduced)
- Show default values of the chart to the user if it is an external chart. (e.g. using helm show values command)

## 8. Add to release notes

- add the component to the release notes draft in RELEASE_NOTES.md
