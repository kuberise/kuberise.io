#!/bin/bash

# Enable command echoing
set -x

# Define network name
NETWORK="platform"

##### ---- start clean
docker stop registry
docker rm registry
minikube stop
minikube delete
docker network rm $NETWORK
##### ----

# Create network with subnet configuration
docker network create --subnet=172.18.0.0/16 $NETWORK

mkdir -p certs

# Generate a new certificate with SANs
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout ~/.registry/certs/registry.key -out ~/.registry/certs/registry.crt \
  -subj "/CN=registry" \
  -addext "subjectAltName=DNS:registry,DNS:registry.onprem.kuberise.dev,DNS:localhost,IP:127.0.0.1"

minikube start --ports=80:30080,443:30443 --cpus=max --memory=max --network=$NETWORK
minikube cp ~/.registry/certs/registry.crt /etc/docker/certs.d/registry:5000/ca.crt


docker run -d \
  --name registry \
  --net $NETWORK \
  -v ~/.registry/certs:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -p 5001:5000 \
  registry:2

docker pull nginx:alpine
docker tag nginx:alpine localhost:5001/api:v1
docker push localhost:5001/api:v1

docker pull localhost:5001/api:v1 # test

minikube ssh -- docker pull registry:5000/api:v1 # test


# stop start test
docker stop registry
docker start registry

# Modify your helm values to use the local registry address
# For example, for kube-prometheus-stack:
# helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
#   --set global.imageRegistry=registry:5000

# trust the certificate of the registry in host docker desktop
mkdir -p ~/.docker/certs.d/localhost:5001
cp ~/.registry/certs/registry.crt ~/.docker/certs.d/localhost:5001/ca.crt
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/.registry/certs/registry.crt

# Show the list of current repositories in local registry
curl -sS https://localhost:5001/v2/_catalog | yq -P
