# Upgrade Script Reference

This document describes the structure, flow, and implementation details of `scripts/upgrade.sh`, the script that checks and updates external Helm chart versions used by the kuberise.io platform.

## Overview

The script automates discovery of newer Helm chart versions and helps keep the platform up to date. It:

- Parses `app-of-apps/values.yaml` for applications that reference external charts (`chart` + `repoURL` + `targetRevision`)
- Checks the ArgoCD and Cilium chart versions hardcoded in `scripts/install.sh`
- Compares each current version against the latest available from the chart repositories
- Updates versions when newer releases are available (interactive or automatic)

The script is **read-only in list mode** (`-l`) and **write-only when updates are applied** in update mode. It does not deploy anything; it only modifies YAML and shell constants in the repository.

## Prerequisites

**Required tools:**

- `curl` – fetches `index.yaml` from HTTP-based Helm repositories
- `yq` – parses YAML (`values.yaml`) and extracts chart metadata from index.yaml
- `helm` – used to fetch chart metadata from OCI registries (when `repoURL` is `oci://...`)
- `grep`, `sed`, `awk` – for parsing and updating files

**Working directory:** Run from the repository root so paths `app-of-apps/values.yaml` and `scripts/install.sh` resolve correctly. The script exits with an error if either file is missing.

**Network:** Update mode needs network access to fetch `index.yaml` from chart repositories or to query OCI registries. List mode only reads local files.

## Command-Line Options

| Option | Long form | Description |
|--------|-----------|-------------|
| `-h` | `--help` | Show the help message and exit. Ignores other options. |
| `-y` | – | Automatic update mode. Apply all available updates without asking for confirmation. |
| `-l` | `--list` | List mode. Print all chart references and their current versions. No version checks, no updates. Exits after listing. |

**Default behavior:** Without `-y`, the script runs interactively and prompts for each available update with `Update X from A to B? (y/n)`.

### Examples

```bash
./scripts/upgrade.sh              # Interactive: prompts before each update
./scripts/upgrade.sh -y          # Apply all updates automatically
./scripts/upgrade.sh -l          # List all chart references, no updates
./scripts/upgrade.sh --list      # Same as -l
./scripts/upgrade.sh --help      # Show help
```

## How It Works

### Data Sources

The script reads from two places:

1. **`app-of-apps/values.yaml`**  
   Applications under `ArgocdApplications` that have `chart`, `repoURL`, and `targetRevision` fields. These are external Helm charts managed by Argo CD. The script uses `yq` to extract application names and their `chart`, `targetRevision`, and `repoURL` values.

2. **`scripts/install.sh`**  
   The constants `ARGOCD_CHART_VERSION` and `CILIUM_CHART_VERSION` (and their associated repos). These charts are installed directly by the install script before Argo CD takes over. The script parses these via `grep` and updates them via `sed`.

### Version Discovery

For each chart, the script determines the latest version:

- **HTTP repositories** (e.g. `https://argoproj.github.io/argo-helm`): Fetches `{repoURL}/index.yaml` with `curl`, then uses `yq` to read `.entries.{chart}[0].version`. Helm index.yaml lists versions in descending order, so index `[0]` is the latest.

- **OCI registries** (e.g. `oci://ghcr.io/...`): Runs `helm show chart oci://repo/chart` and extracts the `version` field from the chart metadata.

### Update Logic

For each chart:

1. Read current version from the appropriate source (values.yaml or install.sh).
2. Fetch latest version from the repository.
3. If latest > current and fetch succeeded, offer to update (or apply automatically with `-y`).
4. If fetch failed, report "Failed to check version. Please verify manually."
5. If current equals latest, report "Already using the latest version."

Updates are applied in place:

- **values.yaml:** `update_target_revision` uses `awk` to replace the `targetRevision` line under the matching application block. This preserves blank lines and comments (unlike `yq -i`).
- **install.sh:** `update_install_script_version` uses `sed` to replace the `readonly VAR_CHART_VERSION="..."` line.

## Script Modes

### List Mode (`-l`, `--list`)

1. Prints a table of applications from `values.yaml`: APPLICATION, CHART, VERSION, REPOSITORY.
2. Prints a second table for install script charts: INSTALL SCRIPT, CHART, VERSION, REPOSITORY.
3. Exits. No network calls, no updates.

Use this to audit current versions without making changes.

### Update Mode (default, or with `-y`)

1. Iterates over all external chart applications from `values.yaml`.
2. For each, fetches the latest version, compares, and updates if newer (with or without confirmation).
3. Iterates over ArgoCD and Cilium in `install.sh`, same process.
4. Prints a summary per chart and "Finished checking all external charts" at the end.

## Install Script Charts

These charts are installed by `install.sh` before the app-of-apps deploys. They are not in `values.yaml`:

| Variable prefix | Chart name | Repository |
|-----------------|------------|------------|
| ARGOCD | argo-cd | https://argoproj.github.io/argo-helm |
| CILIUM | cilium | https://helm.cilium.io/ |

The script updates the `readonly X_CHART_VERSION="..."` lines in `install.sh` when newer versions are found.

## Output Format

**List mode:**

```
Listing all external chart references:
APPLICATION                    CHART                     VERSION         REPOSITORY
------------------------------------------------------------------------------------------------------------
argocd                         argo-cd                   9.4.2           https://argoproj.github.io/argo-helm
...

INSTALL SCRIPT                 CHART                     VERSION         REPOSITORY
------------------------------------------------------------------------------------------------------------
ARGOCD                         argo-cd                   9.4.2           https://argoproj.github.io/argo-helm
CILIUM                         cilium                    1.19.0          https://helm.cilium.io/
```

**Update mode (per chart):**

```
Checking: argocd (argo-cd)
  Current version: 9.4.2
  Repository: https://argoproj.github.io/argo-helm
  New version available: 9.5.0
  Update argocd from 9.4.2 to 9.5.0? (y/n)
----------------------------------------
```

## Implementation Notes

- **Ordering:** The script processes charts in the order they appear in `values.yaml` (from `yq` output) and then the install script charts in a fixed order (ARGOCD, CILIUM).
- **Error handling:** If a version check fails for one chart, the script reports the failure and continues with the next chart. It does not exit early.
- **Compatibility:** Supports both HTTP-based Helm repos and OCI registries as used in the kuberise.io app-of-apps configuration.
