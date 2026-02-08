# ADR-0008: Multi-Source Applications for Split Repository Topology

## Status

Deferred

## Context

The app-of-apps template currently uses single-source ArgoCD Applications, where both the Helm chart templates and the value files reside in the same Git repository. Value files are referenced via relative paths:

```yaml
helm:
  ignoreMissingValueFiles: true
  valueFiles:
    - ../../values/defaults/platform/{{ $name }}/values.yaml
    - ../../values/{{ $.Values.global.clusterName }}/platform/{{ $name }}/values.yaml
```

This design is simple and works well when one team manages both the platform templates and the configuration values. However, there are use cases where the value files should live in a different repository than the templates.

### Use cases for a split repository topology

#### 1. Developer-owned application configuration

Developer teams deploy their applications using shared Helm chart templates (e.g., `generic-deployment`), but the values that configure those deployments (image tag, replicas, resource limits, environment variables, feature flags) are application-specific. Developers should be able to change these values in their own application repository without needing write access to the platform repository. This enables:

- Developers to manage their own deployment configuration alongside their application source code
- Faster iteration cycles (no pull request to the platform repo for a config change)
- Clear ownership boundaries between platform and application teams

#### 2. Separate configuration repository for regulated environments

In regulated environments (financial services, healthcare), the configuration that controls production deployments may need to be in a separate repository with stricter access controls, audit trails, and approval workflows than the platform templates repository.

#### 3. Multi-tenant platform with per-tenant configuration

When the platform serves multiple tenants (business units, customers), each tenant's configuration could live in their own repository while sharing the same set of platform templates.

### Current pre-wiring

The `values.yaml` already defines a separate source for values, and `install.sh` injects these parameters:

```yaml
# values.yaml
global:
  spec:
    source:
      repoURL: x
      targetRevision: x
    values:
      repoURL: x         # <-- separate values source
      targetRevision: x   # <-- separate values source
```

```bash
# install.sh injects both sources
- name: global.spec.source.repoURL
  value: $git_repo
- name: global.spec.values.repoURL
  value: $git_repo          # same repo today, but can differ
- name: global.spec.values.targetRevision
  value: $git_revision
```

Although `global.spec.values.repoURL` and `global.spec.values.targetRevision` are not referenced anywhere in the ArgoCD Application template today, we intentionally keep them in the global values section of `values.yaml` (lines 13-15) and in `install.sh` so the plumbing is ready when we implement multi-source support in the future. Today `install.sh` sets both `global.spec.source` and `global.spec.values` to the same repository, but the separation exists so they can diverge when a split repository topology is needed.

## Decision

We defer the implementation of multi-source Applications to a future date. The `global.spec.values` parameters in `values.yaml` and `install.sh` are retained as intentional forward-looking plumbing, documented by this ADR.

### Why defer

1. **ArgoCD multi-source is still Beta.** The UI and CLI do not fully support multiple sources and behave as if only the first source is specified. This impacts day-to-day operations and debugging.

2. **Known autosync issues.** ArgoCD versions 2.14+ have reported issues where autosync in multi-source Applications detects changes but fails to execute them (see [argoproj/argo-cd#21869](https://github.com/argoproj/argo-cd/issues/21869)).

3. **No immediate need.** All templates and values currently reside in the same repository, and the single-source design serves existing clusters well.

### Future implementation

When ArgoCD multi-source reaches stable status, the template change would look like this:

```yaml
{{- if eq $applicationType "helm" }}
  sources:
    - repoURL: {{ default $.Values.global.spec.source.repoURL $app.repoURL }}
      targetRevision: {{ default $.Values.global.spec.source.targetRevision $app.targetRevision }}
      {{- if hasKey $app "chart" }}
      chart: {{ $app.chart }}
      {{- else if hasKey $app "path" }}
      path: {{ tpl $app.path $ }}
      {{- else }}
      path: templates/{{ $name }}
      {{- end }}
      helm:
        ignoreMissingValueFiles: true
        valueFiles:
          {{- if hasKey $app "values" }}
          {{- range $app.values }}
          - {{ . }}
          {{- end }}
          {{- else if hasKey $app "valuesFolder" }}
          - $values/values/defaults/{{ $app.valuesFolder }}/{{ $name }}/values.yaml
          - $values/values/{{ $.Values.global.clusterName }}/{{ $app.valuesFolder }}/{{ $name }}/values.yaml
          {{- else }}
          - $values/values/defaults/platform/{{ $name }}/values.yaml
          - $values/values/{{ $.Values.global.clusterName }}/platform/{{ $name }}/values.yaml
          {{- end }}
        parameters:
          - name: global.domain
            value: {{ $.Values.global.domain }}
          - name: global.clusterName
            value: {{ $.Values.global.clusterName }}
    - repoURL: {{ default $.Values.global.spec.values.repoURL $app.valuesRepoURL }}
      targetRevision: {{ default $.Values.global.spec.values.targetRevision $app.valuesTargetRevision }}
      ref: values
{{- end }}
```

Key points about this approach:

- **`$values` and Go template variables coexist without conflict.** The `$values` reference in `valueFiles` paths is literal text (outside `{{ }}` delimiters) and is passed through unchanged by the Go template engine. ArgoCD resolves `$values` later during source reconciliation. The Go template variables (`{{ $name }}`, `{{ $.Values.global.clusterName }}`) are resolved during Helm rendering. These two stages are independent.

- **Per-application values source override.** The `$app.valuesRepoURL` and `$app.valuesTargetRevision` fields would allow individual applications to point to a different values repository, enabling the developer-owned configuration use case.

- **Backward compatible.** When `global.spec.values.repoURL` equals `global.spec.source.repoURL` (the default today), the behavior is functionally identical to the current single-source design -- just structured differently.

### Example: developer-owned application values

A developer team's frontend application could store its deployment values in its own repository:

```yaml
# app-of-apps/values-aks.yaml
ArgocdApplications:
  show-env:
    enabled: true
    path: templates/generic-deployment
    valuesFolder: applications
    namespace: frontend
    team: frontend
    valuesRepoURL: https://github.com/frontend-team/show-env.git
    valuesTargetRevision: main
```

ArgoCD would pull the Helm chart from the platform repo and the value files from the frontend team's repo, giving developers full control over their application configuration.

## Consequences

- The `global.spec.values` fields in `values.yaml` and `install.sh` are retained as documented forward-looking plumbing, not dead code.
- No template changes are made now. The current single-source design remains in effect.
- When ArgoCD multi-source reaches stable status and the known issues are resolved, this ADR serves as the implementation guide.
- The install script will need to accept an optional separate values repository URL when this feature is implemented.
- Value file paths in the `values` field (ADR-0005) would need to use `$values/` prefix instead of relative `../../` paths when split-repo mode is active.
