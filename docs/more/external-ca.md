# Using a Self-Signed CA with cert-manager and Kubernetes

This guide explains how to create a self-signed Certificate Authority (CA), use it with cert-manager, and add it to a Minikube or kind cluster.

## Step 1: Create a Self-Signed CA

First, create a private key and a self-signed CA certificate:

```bash
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -subj "/CN=my-ca" -days 10000 -out ca.crt
```

## Step 2: Use the CA with cert-manager

Create a Secret in Kubernetes to store the CA certificate and private key:

```bash
kubectl create secret tls ca-key-pair --cert=ca.crt --key=ca.key -n cert-manager
```

Then, create a `ClusterIssuer` that uses this CA:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-clusterissuer
spec:
  ca:
    secretName: ca-key-pair
```

## Step 3: Add the CA to a Minikube Cluster

Copy the CA certificate to the Minikube VM and update the CA certificates:

```bash
minikube ssh "sudo mkdir -p /usr/share/ca-certificates/extra && echo $(cat ca.crt) | sudo tee /usr/share/ca-certificates/extra/ca.crt"
minikube ssh "echo 'extra/ca.crt' | sudo tee -a /etc/ca-certificates.conf && sudo update-ca-certificates"
```

## Step 4: Add the CA to a kind Cluster

To add the CA to a kind cluster, you need to modify the kind configuration file to mount the CA certificate into the control plane nodes:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
  - hostPath: /path/to/ca.crt
    containerPath: /usr/local/share/ca-certificates/ca.crt
```

Replace `/path/to/ca.crt` with the path to your CA certificate.

Then, create a new kind cluster with this configuration:

```bash
kind create cluster --config kind-config.yaml
```

After creating the cluster, you need to update the CA certificates on each control plane node:

```bash
docker exec -it <node-name> sh -c "update-ca-certificates"
```

Replace `<node-name>` with the name of each control plane node.

After following these steps, your self-signed CA should be trusted by the Minikube or kind cluster, and cert-manager should issue certificates signed by this CA.

Please note that you need to replace the placeholders with the actual values. Also, these instructions assume that you have `openssl`, `kubectl`, `minikube`, and `kind` installed on your machine.
