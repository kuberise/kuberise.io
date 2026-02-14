# ADR-0016: Install Script Improvements

## Status

Accepted

## Context

The `scripts/install.sh` script is the entry point for deploying the kuberise.io platform on a Kubernetes cluster. Over time, as more components were added (Cilium, OAuth2 clients, CA certificates), the script grew without a corresponding improvement in its structure or robustness. A review identified several categories of issues:

1. **Positional arguments.** The script accepted 7 positional parameters (`CONTEXT`, `CLUSTER_NAME`, `REPO_URL`, `TARGET_REVISION`, `DOMAIN`, `CLUSTER_ID`, `REPOSITORY_TOKEN`). With optional parameters in the middle and defaults for some positions, callers had to remember the exact order and pass placeholder values for parameters they didn't need. The `CLUSTER_ID` parameter was defined but never used anywhere in the script, yet it shifted `REPOSITORY_TOKEN` to the 7th position, causing a mismatch with the documented 6-parameter interface.

2. **Idempotency bugs.** The `label_secret` function used `kubectl label` without the `--overwrite` flag, which causes an error if the label already exists. Under `set -e`, this aborted the entire installation on re-runs. The OAuth2-proxy `cookie_secret` was regenerated on every run instead of being retrieved from the existing secret, invalidating all user sessions on each re-run.

3. **SIGPIPE risk with pipefail.** The `generate_random_secret` function piped `openssl rand | tr | head`. When `head` consumed enough bytes and closed its stdin, `tr` received SIGPIPE and exited with code 141. Under `set -eo pipefail`, this could abort the script.

4. **Scattered constants.** Helm chart versions were hardcoded inside functions. Namespace names were defined as individual variables (`NAMESPACE_ARGOCD`, `NAMESPACE_CNPG`, etc.) but also hardcoded inside `generate_ca_cert_and_key` as a separate list, creating duplication that could drift.

5. **No validation.** The script did not check whether the cluster values directory existed, whether the Kubernetes context was reachable, or whether the admin password was the insecure default. Errors surfaced deep in the script as confusing Helm or kubectl failures.

6. **Fragile secret creation.** The `create_secret` function accepted `--from-literal` pairs as a single space-separated string (`$key_values`), relying on word splitting. Callers also smuggled `--type=...` through the same parameter, making the interface misleading. Values containing spaces would silently break.

7. **No cleanup guarantees.** The `install_cilium` function created a temporary values file via `mktemp` and cleaned it up manually after Helm completed. If the function failed between creation and cleanup, the temp file was leaked.

8. **Noisy re-run output.** On idempotent re-runs, every `kubectl apply` printed `unchanged` lines for resources that hadn't changed, drowning out the lines that actually mattered.

9. **Flat structure.** All logic was at the top level of the script with no grouping into phases. It was difficult to understand the high-level flow or comment out a specific phase for debugging.

## Decision

We rewrote `scripts/install.sh` with the following design decisions:

### Named flags instead of positional arguments

The script now uses `--context`, `--cluster`, `--repo`, `--revision`, `--domain`, and `--token` flags parsed in a `while/case` loop. This is self-documenting at the call site, eliminates positional ambiguity, and allows adding new flags without breaking existing invocations. A `--help` flag prints full usage documentation including environment variables. The unused `CLUSTER_ID` parameter was removed.

### Centralized constants

All chart versions (`ARGOCD_CHART_VERSION`, `CILIUM_CHART_VERSION`), repository URLs, and namespace lists are defined as `readonly` variables at the top of the script. The hardcoded namespace list inside `generate_ca_cert_and_key` was replaced with a dedicated `CA_BUNDLE_NAMESPACES` array. Namespace creation iterates over the `NAMESPACES` array instead of repeating individual calls.

### Structured logging

Four logging functions (`log_info`, `log_warn`, `log_error`, `log_step`) replace bare `echo` statements. Output is prefixed with `[INFO]`, `[WARN]`, or `[ERROR]`, and `log_step` prints phase headers. Warnings and errors go to stderr. This makes output scannable and greppable in CI logs.

### Idempotent label_secret

The `label_secret` function now includes `--overwrite`, making it safe to call on re-runs when the label already exists.

### Persistent cookie secret

The OAuth2-proxy cookie secret is now retrieved via `get_or_generate_secret` (like all other secrets) instead of being regenerated on every run. This preserves existing user sessions across re-runs.

### SIGPIPE-safe random secret generation

The `generate_random_secret` function now uses bash parameter expansion (`${raw//[^a-zA-Z0-9]/}` and `${raw:0:32}`) instead of piping through `tr | head`. This eliminates the SIGPIPE risk entirely.

### Proper create_secret interface

The `create_secret` function now uses `shift 3` and `"$@"` to pass remaining arguments directly to `kubectl create secret`. Each argument is properly quoted at the call site. No more word-splitting of a concatenated string.

### Early validation

A `validate` function runs after argument parsing and checks:
- All required tools are installed
- Required flags (`--context`, `--repo`) are provided
- The cluster values directory (`values/$CLUSTER_NAME`) exists (with a helpful message listing available clusters on failure)
- The Kubernetes cluster is reachable via the given context
- A warning is printed when the default admin password is in use

### Global cleanup trap

A `TEMP_FILES` array and an `EXIT` trap guarantee cleanup of temporary files even if the script fails. Functions call `make_temp_file` instead of `mktemp` directly.

### Filtered kubectl apply output

A `filter_unchanged` function (piped after every `kubectl apply`) suppresses `unchanged` lines, so re-run output only shows resources that were actually `created` or `configured`.

### Phase-based main function

The script's execution flow is organized into named phases called from a `main` function:
1. `create_all_namespaces`
2. `configure_repo_access`
3. `generate_ca_cert_and_key`
4. `create_database_secrets`
5. `install_cilium`
6. `create_application_secrets`
7. `install_argocd`
8. `deploy_app_of_apps`
9. `configure_oauth2_clients`

Each phase is preceded by a `log_step` header. This provides a readable table of contents, clear output boundaries, and makes it easy to comment out a phase during debugging.

### Configurable Gitea admin password

The previously hardcoded Gitea admin password (`adminadmin`) is now configurable via the `GITEA_ADMIN_PASSWORD` environment variable, defaulting to the value of `ADMIN_PASSWORD`.

### Consistent quoting

All variable references in command arguments are properly quoted throughout the script, preventing potential issues with values containing special characters.

### Alternatives considered

- **Keep positional arguments with backward compatibility.** We considered supporting both positional and named arguments. Rejected because maintaining two parsing paths adds complexity and the migration is straightforward (only `start.sh` and documentation need updating).

- **Use a configuration file instead of flags.** We considered reading parameters from a YAML or `.env` file. Rejected because the script is typically run once per cluster and the named flags are sufficient. A config file would add a dependency (a YAML parser) and another file to maintain.

- **Suppress all kubectl output.** We considered redirecting all kubectl output to `/dev/null`. Rejected because `created` and `configured` lines provide useful feedback, especially on first runs. Only `unchanged` lines are filtered.

## Consequences

### Positive

- **Safe re-runs.** All idempotency bugs are fixed. The script can be run repeatedly without errors or side effects (broken sessions, leaked temp files).
- **Self-documenting invocations.** Named flags make it immediately clear what each parameter means at the call site, both in documentation and in other scripts like `start.sh`.
- **Faster debugging.** Phase headers and filtered output make it easy to identify which phase failed and what actually changed.
- **Easier maintenance.** Chart versions and namespace lists are centralized. Adding a new namespace or bumping a chart version requires changing one line at the top.
- **Safer for production.** Validation catches common mistakes (wrong context, missing directory, default password) before they cause cryptic failures deep in the installation.

### Negative

- **Breaking change.** Existing scripts and documentation that use the positional argument syntax must be updated. All known consumers (`start.sh`, README, docs, `.cursorrules`) were updated as part of this change.
- **Slightly longer script.** The added logging, validation, and phase functions increase the script from 537 to ~700 lines. The additional lines are structure and safety, not additional business logic.
