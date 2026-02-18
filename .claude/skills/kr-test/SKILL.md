---
name: kr-test
description: Test kr CLI changes on a local k3d cluster
disable-model-invocation: true
---

# Test kr CLI on Local k3d Cluster

Run a local smoke test of `kr` changes using k3d clusters.

## Steps

### 1. Start local clusters (if not running)

Check if k3d clusters exist:
```bash
k3d cluster list
```

If no clusters exist, start them:
```bash
./scripts/k3d+registry/start.sh
```

This creates two clusters: `k3d-shared` and `k3d-dev`.

### 2. Bootstrap with kr init

```bash
./scripts/kr init \
  --context k3d-dev \
  --cluster dev-app-onprem-one \
  --domain k3d.kuberise.dev
```

### 3. Deploy with kr deploy

```bash
./scripts/kr deploy \
  --context k3d-dev \
  --cluster dev-app-onprem-one \
  --repo https://github.com/kuberise/kuberise.io.git \
  --revision main \
  --domain k3d.kuberise.dev
```

### 4. Verify

Check ArgoCD application status:
```bash
kubectl get applications -n argocd --context k3d-dev
```

Summarize:
- How many applications were created
- How many are synced/healthy
- Any errors or degraded applications

### 5. Test dry-run (if relevant)

If testing dry-run changes:
```bash
./scripts/kr deploy --dry-run \
  --context k3d-dev \
  --cluster dev-app-onprem-one \
  --repo https://github.com/kuberise/kuberise.io.git \
  --revision main \
  --domain k3d.kuberise.dev
```

Verify the output is valid YAML (all informational messages use `#` comment format).

### Cleanup (optional)

```bash
./scripts/k3d+registry/delete-all.sh
```

## Notes

- Always use `./scripts/kr` (local version) not the installed `kr` when testing changes
- The k3d clusters use Cilium as CNI, pass `--cilium` to `kr init` if needed
