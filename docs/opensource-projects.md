
From `values.yaml` and the official CNCF project lists, these are the CNCF projects used in kuberise.io:

## CNCF projects in values.yaml

| App in values.yaml | CNCF project | Maturity |
|--------------------|-------------|----------|
| **argocd-image-updater** | **Argo** | Graduated |
| **backstage** | **Backstage** | Incubating |
| **cert-manager** | **cert-manager** | Graduated |
| **cilium** | **Cilium** | Graduated |
| **postgres-operator** (cloudnative-pg) | **CloudNativePG** | Sandbox |
| **external-secrets** | **External Secrets** | Sandbox |
| **external-dns** | *(Kubernetes SIG project; part of Kubernetes/CNCF ecosystem)* | — |
| **ingress-nginx** | **Kubernetes** (Ingress NGINX controller) | Graduated |
| **keda** | **KEDA** | Graduated |
| **keycloak** | **Keycloak** | Incubating |
| **kyverno** | **Kyverno** | Incubating |
| **metallb** | **MetalLB** | Sandbox |
| **oauth2-proxy** | **OAuth2 Proxy** | Sandbox |
| **opencost** | **OpenCost** | Incubating |
| **kube-prometheus-stack** | **Prometheus** | Graduated |
| **k8sgpt** | **K8sGPT** | Sandbox |

---

## Count (excluding duplicates and config apps)

**14 CNCF projects:**

1. Argo
2. Backstage
3. cert-manager
4. Cilium
5. CloudNativePG
6. External Secrets
7. KEDA
8. Keycloak
9. Kyverno
10. MetalLB
11. OAuth2 Proxy
12. OpenCost
13. Prometheus (via kube-prometheus-stack)
14. K8sGPT

---

## Not CNCF projects in values.yaml

- **Gitea** – community project
- **Rancher** – SUSE / Rancher Labs
- **vcluster** – Loft
- **Tekton** – CDF (Continuous Delivery Foundation), moving toward CNCF but not yet
- **Redis, MinIO, pgAdmin** – vendor/third‑party projects
- **Keycloak Operator** – EPAM / vendor chart
- **Vault, vault-secrets-operator** – HashiCorp
- **NeuVector** – SUSE
- **Loki, Promtail** – Grafana (on CNCF landscape, not CNCF projects)
- **Ollama** – independent
- **Sealed Secrets** – Bitnami Labs
- **AWS Load Balancer Controller** – AWS
- **Metrics Server** – Kubernetes SIG (ecosystem, but not a standalone CNCF project)
