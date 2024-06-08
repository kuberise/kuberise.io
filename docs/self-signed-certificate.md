# Self Signed Certificate

This guide will walk you through the process of using a self-signed certificate, adding namespaces and DNS names, enabling/disabling the certificate, and providing a Certificate Authority (CA) from outside the cluster.

## Using a Self-Signed Certificate

In the `values.yaml` file of cert-manager, you can enable the use of a self-signed certificate by setting the `enabled` field under `selfSignedCertificate` to `true`.

```yaml
selfSignedCertificate:
  enabled: true
```

## Enabling/Disabling the Certificate

You can enable or disable the use of the certificate by changing the `enabled` field under `selfSignedCertificate` in the `values.yaml` file. Set it to `true` to enable and `false` to disable.

```yaml
selfSignedCertificate:
  enabled: true  # Set to false to disable
```

## Providing a CA from Outside the Cluster

If you want to provide a CA from outside the cluster, you first need to generate your CA certificate and key pair, then create a Kubernetes Secret in your cluster in the cert-manager namespace with the generated CA certificate and key.

```bash
openssl req -x509 -new -nodes -keyout ca.key -out ca.crt -subj "/CN=ca.kuberise.local"
kubectl create secret tls ca-key-pair --cert=ca.crt --key=ca.key
```

In the `values.yaml` file, set `createCaCertificate` under `selfSignedCertificate` to `false`. This tells the system to use the existing CA certificate and key pair to issue new certificates.

```yaml
selfSignedCertificate:
  createCaCertificate: false
```

Now, your Helm chart will use the existing CA certificate and key pair to issue new certificates. This way, you can have a fixed CA across cluster changes or reinstallations.
