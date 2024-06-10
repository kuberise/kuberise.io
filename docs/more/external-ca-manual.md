# Creating `ca.key` and `ca.crt`

The `ca.key` and `ca.crt` files are created using the OpenSSL command-line tool. Generating ca.key and ca.crt can be done once and it would be enough for that machine. Here are the steps to create these files:

1. **Generate a new RSA private key**: The following command generates a new 2048-bit RSA private key and saves it to the file `temp/ca.key`.

    ```shellscript
    openssl genrsa -out temp/ca.key 2048
    ```

2. **Create a new self-signed x509 certificate**: The following command creates a new x509 certificate, signs it with the private key created in the previous step, and saves it to the file `temp/ca.crt`. The certificate is valid for 10000 days.

    ```shellscript
    openssl req -x509 -new -nodes -key temp/ca.key -subj "/CN=ca.kuberise.com" -days 10000 -out temp/ca.crt
    ```

# Embedding CA into Kubernetes in Docker (kind)

To embed the CA into Kubernetes in Docker (kind), you need to create a `kind` configuration file that includes the paths to the `ca.crt` and `ca.key` files. Here's an example:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: ./temp/ca.crt
    containerPath: /usr/local/share/ca-certificates/ca.crt
```

