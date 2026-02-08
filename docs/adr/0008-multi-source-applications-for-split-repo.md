# ADR-0008: Multi-Source Applications for Split Repository Topology

## Status

Superseded by ADR-0014

## Context

The app-of-apps template originally used single-source ArgoCD Applications, where both the Helm chart templates and the value files resided in the same Git repository. Value files were referenced via relative paths.

This design was simple and worked well when one team manages both the platform templates and the configuration values. However, there are use cases where the value files should live in a different repository than the templates.

See ADR-0014 for the implementation details.

## Decision

This ADR was originally deferred pending ArgoCD multi-source stability. It has been superseded by ADR-0014 which implements multi-source as part of a broader architectural change to reference external Helm charts directly.

## Consequences

See ADR-0014 for consequences.
