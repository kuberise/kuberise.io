# ADR-0009: JSON Schema Validation for app-of-apps Values

## Status

Accepted

## Context

The `app-of-apps` Helm chart uses a `values.yaml` file where each ArgoCD Application is defined as an entry under `ArgocdApplications`. The most critical field is `enabled`, which controls whether an application is deployed.

Without schema validation, typos in field names are silently ignored by Helm. For example, `enbled: true` instead of `enabled: true` would result in the application not being deployed, with no error message indicating why. Similarly, typos like `namspace`, `pathh`, or `serverSideAply` would be silently ignored, potentially causing unexpected behavior.

This creates a poor operator experience: a single-character typo can cause an application to not deploy, and debugging requires manually comparing the values file against the template to spot the mistake.

## Decision

We add a `values.schema.json` file to the `app-of-apps/` Helm chart directory. Helm automatically validates the merged values against this schema during `helm template`, `helm install`, and `helm upgrade` operations.

The schema enforces:

1. **Required fields**: `enabled` is required for every application entry under `ArgocdApplications`. `clusterName` and `domain` are required under `global`.
2. **No additional properties**: Both application entries and the `global` section use `additionalProperties: false`. Any unrecognized field name (i.e., a typo) causes an immediate validation error.
3. **Type constraints**: `enabled` must be a boolean, `type` must be one of `["helm", "kustomize", "raw"]`, `syncWave` must be an integer, array fields must contain the correct item types, etc.
4. **Structural validation**: The overall structure (global config + application map) is validated, ensuring values files conform to the expected shape.

The schema uses JSON Schema Draft-07, which is the latest draft supported by Helm's underlying `gojsonschema` library.

### Alternatives Considered

- **Helm template-level validation with `required` and `fail`**: Would only catch missing fields, not typos in field names. Also makes templates harder to read.
- **CI-only validation with external tools**: Would not provide feedback during local development with `helm template`.
- **No validation (status quo)**: Typos are silently ignored, leading to debugging overhead.

## Consequences

- Typos in field names are caught immediately at `helm template` / `helm install` / `helm upgrade` time with clear error messages.
- Adding a new field to the ArgoCD Application template requires updating `values.schema.json` to include the new property. Forgetting to do so will cause a validation error when the new field is used (fail-safe behavior).
- The schema must be kept in sync with the template. This is documented in the project rules and the schema file itself includes descriptions for maintainability.
- Helm validates the merged values (base + cluster-specific overrides), so cluster-specific files that only override `enabled` are validated correctly.
- IDE support: editors with YAML/JSON Schema plugins can provide autocomplete and inline validation for values files.
