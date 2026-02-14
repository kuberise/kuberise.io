# ADR-0017: Bash Install Script over Custom CLI Tool

## Status

Accepted

## Context

The kuberise.io platform is bootstrapped by a single bash script (`scripts/install.sh`) that orchestrates kubectl, helm, and openssl commands to take a bare Kubernetes cluster from empty to a fully running platform managed by ArgoCD. After the improvements in ADR-0016, the script is approximately 700 lines with named flags, structured logging, validation, idempotent operations, and a phase-based main function.

As the platform grows, a recurring question is whether bash remains the right language for the installer, or whether we should rewrite it as a compiled CLI tool (e.g., in Go using cobra + client-go). This ADR evaluates that trade-off and records the decision to keep bash for now while identifying the conditions that would justify a future migration.

## Decision

We keep bash as the implementation language for the install script. A dedicated CLI tool (likely in Go) is a valid future option, but the current complexity does not justify the cost of building and maintaining one.

### Why bash is sufficient today

**1. The script is CLI orchestration, not application logic.**
Every operation the script performs is a call to an external CLI tool: `kubectl`, `helm`, `openssl`, `htpasswd`, `yq`, or `cilium`. Bash is the natural composition layer for CLI tools. Using Go or Python would mean either shelling out to the same commands (gaining nothing) or reimplementing them using SDK libraries (adding complexity without adding capability).

**2. Zero additional dependencies.**
The script requires only tools that platform operators already have installed (`kubectl`, `helm`, `openssl`). There is no Go compiler, Python interpreter, Node.js runtime, or package manager to install. For a bootstrap script that runs on a fresh workstation, this is a significant advantage. Every additional dependency is a potential installation failure before the real installation even begins.

**3. The target audience is fluent in bash.**
Kubernetes operators and DevOps engineers read, modify, and debug bash scripts daily. The script is transparent: users can read exactly what will happen, add `set -x` for debugging, or comment out a phase. A compiled binary is opaque by comparison. For an open-source project where users fork and customize the installer, readability and modifiability matter more than type safety.

**4. The script runs infrequently.**
The installer runs once per cluster (or occasionally for re-runs and updates). It is not a long-running service, a hot path, or a user-facing interactive tool. The engineering investment in a compiled CLI is harder to justify for something that runs a handful of times.

**5. After bootstrap, ArgoCD takes over.**
The install script's only job is to get the cluster to the point where ArgoCD manages everything declaratively via GitOps. Once ArgoCD and the app-of-apps are deployed, the script is no longer needed. This limited lifecycle reduces the pressure for the installer to be highly sophisticated.

**6. The script is already well-structured.**
After ADR-0016, the script has named flags with `--help`, input validation, structured logging, idempotent operations, cleanup traps, centralized constants, and a phase-based `main` function. These patterns address the most common criticisms of bash scripts (fragile argument parsing, poor error handling, unreadable output). The script is maintainable at its current size.

### Known limitations of bash that we accept

- **No structured data handling.** Building YAML via `echo >>` (as in the ClusterMesh configuration) is fragile. We mitigate this by using `yq` for reads and keeping YAML construction minimal.
- **No type safety.** Variable typos or wrong argument order are caught at runtime, not compile time. We mitigate this with `set -euo pipefail`, validation, and the `readonly` keyword.
- **Limited testability.** Unit testing bash functions is possible (e.g., with bats) but less mature than Go or Python testing ecosystems. We mitigate this by keeping functions small and side-effect-oriented.
- **Cross-platform differences.** Tools like `base64` and `sed` behave differently on macOS vs Linux. We have not hit blocking issues yet, but this could surface as the user base grows.

### When to reconsider: triggers for a Go CLI

We should revisit this decision if any of the following become true:

1. **Interactive workflows.** If the installer needs interactive prompts (e.g., a TUI for selecting components, cluster wizards, guided setup), bash is the wrong tool and a Go CLI with a library like bubbletea would be appropriate.
2. **Cross-platform distribution.** If we need to distribute the installer as a single binary (e.g., via `brew install kuberise`, a GitHub release binary, or a container image), Go's cross-compilation is a natural fit.
3. **Kubernetes API beyond kubectl.** If the installer needs to watch resources, wait for conditions with backoff, or interact with the Kubernetes API in ways that kubectl does not support well, client-go would be more reliable than parsing kubectl output.
4. **Script exceeds ~1000 lines.** If the script grows significantly beyond its current size, the lack of modules, imports, and type checking will make it harder to maintain. A Go CLI with separate packages would scale better.
5. **Plugin or extension system.** If users need to extend the installer with custom phases or hooks, a Go CLI with a plugin interface would be more robust than sourcing additional bash files.

### Alternatives considered

- **Go CLI (cobra + client-go).** The most likely future direction. Provides type safety, cross-compilation, single-binary distribution, and direct Kubernetes API access. Rejected for now because the development and maintenance cost is significant (a new repository or module, CI/CD for binaries, release management, documentation) and the current bash script covers all requirements.

- **Python with kubernetes-client.** Better data structures and error handling than bash, with a lower barrier to entry than Go. Rejected because it adds a Python runtime dependency, and the kubernetes-client library often lags behind kubectl in feature support. The script would still shell out to helm and openssl.

- **Ansible.** Designed for idempotent infrastructure orchestration with good error reporting and retry logic. Rejected because it adds a heavy dependency (Python + Ansible + collections), its YAML-based playbook syntax is less transparent for simple command sequences than bash, and the team does not use Ansible elsewhere.

- **Makefile wrapping bash.** Could provide named targets (`make install`, `make secrets`, `make argocd`) for partial re-runs without changing language. Rejected as a standalone solution because Make's syntax for conditionals and variables is awkward, but we may add a thin Makefile as a convenience wrapper in the future without replacing the bash script.

- **Terraform/Pulumi.** Infrastructure-as-code tools with state management and plan/apply workflows. Rejected because they are designed for provisioning cloud resources, not bootstrapping software on an existing cluster. The state file management adds operational burden, and Helm/ArgoCD are already the declarative layer.

## Consequences

### Positive

- **No new toolchain.** Contributors do not need to learn a new build system, compile anything, or manage binary releases. The install script is just a file in the repository.
- **Forkable and customizable.** Users who fork the repository can modify the installer with a text editor. No compilation step stands between a change and testing it.
- **Fast iteration.** Changes to the installer are immediately testable. There is no build, link, or release cycle.
- **Focused investment.** Engineering effort goes into the platform itself (charts, values, ArgoCD configuration) rather than into installer tooling.

### Negative

- **Bash limitations remain.** The known limitations (no structured data, no type safety, limited testing, cross-platform differences) are accepted rather than resolved.
- **Future migration cost.** If we eventually build a Go CLI, the bash logic will need to be reimplemented rather than incrementally refactored. The phase-based structure (ADR-0016) will make this translation straightforward, but it is still a rewrite.
- **No single-binary distribution.** Users must clone the repository and run the script from the working directory. We cannot offer `brew install kuberise` or a downloadable binary.
