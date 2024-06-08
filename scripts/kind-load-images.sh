#!/bin/bash

# Define an array with all the Docker images
images=(
  "public.ecr.aws/docker/library/redis:7.2.4-alpine"
  "bitnami/keycloak:24.0.4-debian-12-r1"
  "quay.io/argoproj/argocd:v2.11.0"
  "quay.io/jetstack/cert-manager-startupapicheck:v1.14.5"
  "quay.io/jetstack/cert-manager-webhook:v1.14.5"
  "quay.io/jetstack/cert-manager-controller:v1.14.5"
  "quay.io/jetstack/cert-manager-cainjector:v1.14.5"
  "mojtabaimani/backstage:1.0"
  "ghcr.io/cloudnative-pg/postgresql:16.1"
  "ghcr.io/cloudnative-pg/cloudnative-pg:1.22.1"
  "quay.io/prometheus-operator/prometheus-config-reloader:v0.71.2"
  "quay.io/prometheus-operator/prometheus-operator:v0.71.2"
  "ghcr.io/dexidp/dex:v2.38.0"
  "grafana/grafana:10.3.1"
  "quay.io/prometheus/prometheus:v2.49.1"
  "grafana/promtail:2.9.3"
  "quay.io/prometheus/node-exporter:v1.7.0"
  "grafana/loki:2.9.2"
  "quay.io/kiwigrid/k8s-sidecar:1.25.2"
  "quay.io/prometheus/alertmanager:v0.26.0"
  "nginx:1.16.0"
)

# Load each image into the kind cluster
for image in "${images[@]}"; do
  echo "Loading image: $image"
  docker pull "$image"
  kind load docker-image "$image"
done

echo "All images have been loaded into the kind cluster."
