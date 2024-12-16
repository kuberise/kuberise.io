#!/bin/bash

# This script loads all the Docker images into the minikube cluster.


# This command configures your shell to use the Docker daemon inside the Minikube VM.
# 'minikube -p minikube docker-env' prints out the necessary environment variables.
# 'eval' executes the output of the 'minikube' command in the current shell.
# eval $(minikube -p minikube docker-env)

# Define an array with all the Docker images
# Command to generate the list of images:
# docker images --format '"{{.Repository}}:{{.Tag}}"' | awk '{printf "  %s\n", $0}' | sed '1i\
# images=(' | sed '$a\
# )'

images=(
  "ghcr.io/kuberise/show-env"
  "nginx:alpine"
  "dpage/pgadmin4:8.13"
  "bitnami/external-dns:0.15.0-debian-12-r4"
  "epamedp/keycloak-operator:1.23.0"
  "quay.io/argoprojlabs/argocd-image-updater:v0.15.0"
  "grafana/grafana:11.3.0"
  "quay.io/prometheus/prometheus:v2.55.0"
  "quay.io/prometheus-operator/prometheus-config-reloader:v0.77.2"
  "quay.io/prometheus-operator/prometheus-operator:v0.77.2"
  "registry.k8s.io/ingress-nginx/controller"
  "registry.k8s.io/ingress-nginx/kube-webhook-certgen"
  "quay.io/kiwigrid/k8s-sidecar:1.28.0"
  "registry.k8s.io/metrics-server/metrics-server:v0.7.2"
  "grafana/loki:2.9.10"
  "quay.io/metallb/controller:v0.14.8"
  "quay.io/metallb/speaker:v0.14.8"
  "registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.13.0"
  "quay.io/prometheus/node-exporter:v1.8.2"
  "quay.io/keycloak/keycloak:25.0.0"
  "quay.io/jetstack/cert-manager-startupapicheck:v1.15.0"
  "quay.io/jetstack/cert-manager-controller:v1.15.0"
  "quay.io/jetstack/cert-manager-webhook:v1.15.0"
  "quay.io/jetstack/cert-manager-cainjector:v1.15.0"
  "public.ecr.aws/docker/library/redis:7.2.4-alpine"
  "quay.io/argoproj/argocd:v2.11.0"
  "grafana/promtail:3.0.0"
  "quay.io/prometheus/alertmanager:v0.27.0"
  "ghcr.io/cloudnative-pg/postgresql:16.1"
  "ghcr.io/cloudnative-pg/cloudnative-pg:1.22.1"
  "ghcr.io/dexidp/dex:v2.38.0"
  "quay.io/frrouting/frr:9.1.0"
  "nginxinc/nginx-unprivileged:1.20.2-alpine"
  "nginx:1.16.0"
)

# Load each image into the minikube cluster
# for image in "${images[@]}"; do
#   echo "Pull image: $image"
#   docker pull "$image"
# done

# echo "All images have been pulled locally."


# Load each image into the minikube cluster
for image in "${images[@]}"; do
  echo "Loading image into minikube: $image"
  minikube -p minikube image load "$image" --daemon # fetch the image directly from your local Docker daemon. to avoid unnecessary network transfers or registry operations.
done

echo "All images have been loaded into the minikube cluster."
