# Why kuberise.io?

kuberise.io is a free, open-source Internal Developer Platform (IDP) for Kubernetes. It gives your team a production-ready platform out of the box so developers can focus on building business applications instead of wiring up infrastructure.

## Key Benefits

### One-Command Installation
Get a fully operational platform with a single `install.sh` command. No weeks of manual setup, no deep Kubernetes expertise required to get started. From zero to a working developer platform in minutes.

### GitOps by Design
Every piece of configuration lives in Git. Changes are tracked, reviewed, and auditable. ArgoCD continuously reconciles your desired state with the actual cluster, ensuring your platform never drifts from what's declared in code.

### Multi-Cluster, Multi-Cloud, Multi-Environment
Run the same platform across AWS (EKS), Azure (AKS), Google Cloud (GKE), on-premises, and even air-gapped environments. Each cluster gets its own configuration layer while sharing a common set of defaults -- no duplication, no divergence.

### 40+ Pre-Integrated Components
A curated catalog of production-proven tools, all wired together and ready to use:

- **Developer Portal** -- Backstage for a unified developer experience
- **Identity & Access** -- Keycloak, OAuth2 Proxy for SSO and fine-grained access control
- **Secrets Management** -- Vault, External Secrets Operator, Sealed Secrets
- **Monitoring & Observability** -- Prometheus, Grafana, Loki, Promtail, OpenCost
- **Databases** -- CloudNativePG (PostgreSQL Operator), pgAdmin, Redis
- **Object Storage** -- MinIO
- **Networking** -- Ingress NGINX (internal & external), MetalLB, External DNS, Cilium
- **Security & Policy** -- Cert Manager, Kyverno, NeuVector
- **CI/CD** -- Tekton, ArgoCD Image Updater
- **AI Tools** -- Ollama, K8sGPT
- **Multi-Tenancy** -- vcluster, Rancher, team namespaces, KEDA
- **Git Hosting** -- Gitea for in-cluster Git repositories

### Modular and Composable
Every component is independently toggleable with a single `enabled: true/false` flag. Start small with just the essentials, then incrementally add components as your needs grow. No all-or-nothing decisions.

### Layered Configuration with Smart Defaults
Sensible defaults ship for every component. Cluster-specific overrides are layered on top only when needed. Missing override files are silently ignored, keeping your repository clean and avoiding boilerplate.

### Standardized Application Deployment
The included `generic-deployment` Helm chart provides a reusable template for deploying any application. Developers describe their app with simple values -- the platform handles ingress, TLS, service accounts, and more.

### Team Self-Service and Multi-Tenancy
Built-in team namespace management and Keycloak integration let you onboard teams with proper isolation, RBAC, and SSO from day one. Each team gets its own namespace with appropriate policies applied automatically.

### Cost Visibility
OpenCost integration gives you per-namespace, per-team cost breakdowns so you can understand and optimize your cloud spend without additional tooling.

### AI-Powered Operations
K8sGPT diagnoses cluster issues using AI, and Ollama provides an in-cluster LLM inference server for AI-powered developer workflows.

### Local Development Made Easy
Included k3d scripts spin up a multi-cluster local environment with a Docker registry proxy for fast image pulls. Develop and test your entire platform stack on a laptop before pushing to production.

### Sync Waves for Ordered Deployments
ArgoCD sync waves ensure components are deployed in the correct order -- dependencies come up before the services that need them, every time.

### Automated Self-Healing
ArgoCD continuously monitors and auto-heals drift. If someone manually changes a resource in the cluster, it gets corrected back to the declared state automatically.

### No Vendor Lock-In
Fully open source under a permissive license. Fork the repository, customize it to your needs, and own your platform. Works with any standard Kubernetes distribution.

## Who Is It For?

- **Platform teams** building an Internal Developer Platform without starting from scratch
- **DevOps engineers** tired of gluing together dozens of tools manually
- **Startups** that need production-grade infrastructure without a dedicated platform team
- **Enterprises** managing multiple clusters across clouds and environments
- **Teams adopting GitOps** who want a proven, opinionated starting point

## Get Started

1. Fork the repository
2. Clone it locally
3. Run the install script
4. Start deploying applications

That's it. Your Internal Developer Platform is ready.

Learn more at [kuberise.io](https://kuberise.io).
