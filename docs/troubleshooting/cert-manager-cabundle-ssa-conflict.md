# cert-manager webhook caBundle not injected (ServerSideApply conflict)

## Symptoms

- cert-manager pods are all Running, but the app shows as **Degraded** in ArgoCD
- The `cert-manager-startupapicheck` Job fails with:
  ```
  failed calling webhook "webhook.cert-manager.io": tls: failed to verify certificate: x509: certificate signed by unknown authority
  ```
- Downstream apps that depend on cert-manager CRDs (e.g. capi-operator creating `Issuer` or `Certificate` resources) fail with:
  ```
  Issuer.cert-manager.io "" not found
  ```
- Manually clicking Sync in ArgoCD resolves it temporarily, but it breaks again on the next self-heal cycle

## Root cause

When ArgoCD deploys cert-manager with `ServerSideApply=true` (the default in kuberise), ArgoCD claims ownership of all fields in the `ValidatingWebhookConfiguration`, including the `caBundle` field. The cert-manager cainjector component is responsible for patching the CA certificate into this field, but it cannot because ArgoCD owns it via SSA.

The result: the `caBundle` stays empty, the API server cannot verify TLS when calling the webhook, and all cert-manager custom resource operations (Issuer, Certificate, etc.) fail.

This affects every cluster where cert-manager is deployed via ArgoCD with ServerSideApply enabled.

## Fix

Two settings are needed in the cert-manager app definition in `app-of-apps/values-base.yaml`:

```yaml
cert-manager:
  enabled: false
  chart: cert-manager
  repoURL: https://charts.jetstack.io
  targetRevision: v1.20.0-alpha.1
  syncOptions:
    - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: admissionregistration.k8s.io
      kind: ValidatingWebhookConfiguration
      jsonPointers:
        - /webhooks/0/clientConfig/caBundle
    - group: admissionregistration.k8s.io
      kind: MutatingWebhookConfiguration
      jsonPointers:
        - /webhooks/0/clientConfig/caBundle
```

**Why both are needed:**

- `ignoreDifferences` tells ArgoCD to ignore changes to `caBundle` during diff comparison, so it does not revert the field during self-heal
- `RespectIgnoreDifferences=true` tells ArgoCD to exclude those fields from the SSA apply payload entirely, so ArgoCD never claims ownership of `caBundle`, allowing the cainjector to write it

With `ignoreDifferences` alone, ArgoCD still claims field ownership during SSA apply and blocks the cainjector. The `RespectIgnoreDifferences` option is the crucial second piece.

## How to verify

After deploying the fix, check that the caBundle is populated:

```bash
kubectl get validatingwebhookconfiguration cert-manager-webhook \
  -o jsonpath='{.webhooks[0].clientConfig.caBundle}' | wc -c
```

A non-zero result means the cainjector successfully injected the CA. You can also verify cert-manager CRDs are functional:

```bash
kubectl get issuers -A
kubectl get certificates -A
```

## Applies to other operators too

Any operator that patches webhook configurations with CA bundles can hit this same SSA conflict. If you add tools like OPA Gatekeeper or other webhook-based operators, they may need similar `ignoreDifferences` + `RespectIgnoreDifferences` treatment.
