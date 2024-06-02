# Updating the caBundle for the ValidatingWebhookConfiguration

The Kubernetes API server needs to trust the Certificate Authority (CA) that signed the webhook's serving certificate. If you're using a self-signed CA, you need to manually add the CA certificate to the `caBundle` field of the `ValidatingWebhookConfiguration`. Here's how you can do this:

## Step 1: Get the CA certificate

First, you need to get the CA certificate from the Secret where it's stored. You can do this by running the following command:

```bash
kubectl get secret ca-key-pair -o jsonpath="{.data.tls\.crt}" -n cert-manager | base64 --decode > ca.crt
```

This command will output the CA certificate and save it to a file named `ca.crt`.

## Step 2: Encode the CA certificate

Next, you need to encode the CA certificate in base64. You can do this by running the following command:

```bash
cat ca.crt | base64 | tr -d '\n'
```

This command will output the base64-encoded CA certificate.

## Step 3: Update the ValidatingWebhookConfiguration

Finally, you need to update the `caBundle` field of the `ValidatingWebhookConfiguration` with the base64-encoded CA certificate. You can do this by running the following command:

```bash
kubectl patch validatingwebhookconfigurations ingress-nginx-admission --patch '{"webhooks": [{"name": "validate.nginx.ingress.kubernetes.io", "clientConfig": {"caBundle": "<base64-ca-certificate>"}}]}'
```

Replace `<base64-ca-certificate>` with the base64-encoded CA certificate from step 2.

After following these steps, the Kubernetes API server should trust your self-signed CA.
