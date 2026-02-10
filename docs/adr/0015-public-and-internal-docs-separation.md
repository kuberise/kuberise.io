# ADR-0015: Public and Internal Documentation Separation

## Status

Accepted

## Context

The project maintains documentation alongside the source code in the `docs/` directory. This co-location is intentional: when code changes, the related documentation can be updated in the same commit, and AI-assisted development tools can update docs automatically because they share the same repository context.

However, not all documentation is intended for end-users visiting the kuberise.io website. Some documentation is written for project contributors and developers:

- **Architecture Decision Records (ADRs)** document internal design choices and trade-offs for maintainers.
- **Troubleshooting guides** help contributors debug development issues.
- **LinkedIn posts and social media drafts** are marketing materials, not product docs.
- **Contributing guides and development setup** instructions are for developers, not end-users.

At the same time, the kuberise.io website needs to pull documentation from this repository at build time to avoid maintaining docs in two places. Without a clear boundary, internal docs could accidentally be published on the website, or the website build process would need fragile filtering logic (frontmatter flags, naming conventions, manifest files) to decide what to include.

### Alternatives considered

1. **Convention-based filtering** (prefix internal docs with `_` or `.`, filter at build time). Rejected because conventions must be enforced manually, and a forgotten prefix means an internal doc goes public.

2. **Frontmatter-based filtering** (add `public: false` to internal docs). Rejected because a missing frontmatter tag silently publishes an internal doc. The failure mode is the wrong direction.

3. **Explicit manifest file** listing which docs to publish. Rejected because it requires manual maintenance and will drift from the actual docs directory.

## Decision

Split the `docs/` directory into two subdirectories:

- **`docs/public/`** — Documentation published to the kuberise.io website. Written for end-users: platform operators, DevOps engineers, and developers who use kuberise.io. This includes getting started guides, architecture overviews, deployment guides, component documentation, configuration reference, licensing information, and release notes.

- **`docs/internal/`** — Documentation for project contributors only. Never published to the website. This includes ADRs, troubleshooting guides, development notes, social media drafts, and contributing guidelines.

The website build process pulls only from `docs/public/`. The boundary is a directory, not a convention or filter — making it explicit and impossible to accidentally cross.

### Directory structure

```
docs/
  public/                    # Published to kuberise.io website
    getting-started/
    architecture/
    deployment/
    components/
    configuration/
    licensing.md
    release-notes.md
  internal/                  # Project contributors only
    adr/
    troubleshooting/
    linkedin/
    contributing.md
```

## Consequences

### Positive

- **Single source of truth.** Docs live in the project repository, next to the code. No duplication between the project repo and the website repo.
- **Explicit boundary.** The folder structure makes it obvious which docs are public and which are internal. New contributors can understand the distinction immediately.
- **Safe website builds.** The website build process copies or references only `docs/public/`. No filtering logic, no risk of accidental publication of internal docs.
- **AI-friendly.** AI tools working in the repository can be instructed via `.cursorrules` to place docs in the correct folder, maintaining the boundary automatically.

### Negative

- **Slightly deeper paths.** Documentation paths gain one level of nesting (e.g., `docs/public/getting-started/` instead of `docs/getting-started/`). This is a minor inconvenience.
