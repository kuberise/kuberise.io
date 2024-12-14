#!/bin/bash

# Array of images of a minikube cluster after kuberise.io installed, except the ones that are default images in minikube
declare -a images=(
    "ghcr.io/kuberise/show-env"
    "docker.io/library/nginx:alpine"
    "docker.io/dpage/pgadmin4:8.13"
    "docker.io/bitnami/external-dns:0.15.0-debian-12-r4"
    "docker.io/epamedp/keycloak-operator:1.23.0"
    "quay.io/argoprojlabs/argocd-image-updater:v0.15.0"
    "docker.io/grafana/grafana:11.3.0"
    "quay.io/prometheus/prometheus:v2.55.0"
    "quay.io/prometheus-operator/prometheus-config-reloader:v0.77.2"
    "quay.io/prometheus-operator/prometheus-operator:v0.77.2"
    "registry.k8s.io/ingress-nginx/controller"
    "registry.k8s.io/ingress-nginx/kube-webhook-certgen"
    "quay.io/kiwigrid/k8s-sidecar:1.28.0"
    "registry.k8s.io/metrics-server/metrics-server:v0.7.2"
    "docker.io/grafana/loki:2.9.10"
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
    "docker.io/grafana/promtail:3.0.0"
    "quay.io/prometheus/alertmanager:v0.27.0"
    "ghcr.io/cloudnative-pg/postgresql:16.1"
    "ghcr.io/cloudnative-pg/cloudnative-pg:1.22.1"
    "ghcr.io/dexidp/dex:v2.38.0"
    "quay.io/frrouting/frr:9.1.0"
    "docker.io/nginxinc/nginx-unprivileged:1.20.2-alpine"
    "docker.io/library/nginx:1.16.0"
)

# Function to pull images with error handling
pull_image() {
    local image=$1
    echo "Pulling image: $image"
    if docker pull "$image"; then
        echo "Successfully pulled $image"
    else
        echo "Failed to pull $image"
        return 1
    fi
}


# Counter for successful and failed pulls
success_count=0
failed_count=0
failed_images=()

# Pull each image
total_images=${#images[@]}
current_image=0

for image in "${images[@]}"; do
    ((current_image++))
    echo "[$current_image/$total_images] Pulling $image"

    if pull_image "$image"; then
        ((success_count++))
    else
        ((failed_count++))
        failed_images+=("$image")
    fi
    echo "----------------------------------------"
done

# Print summary
echo "Pull Summary:"
echo "Total images: $total_images"
echo "Successfully pulled: $success_count"
echo "Failed to pull: $failed_count"

if [ ${#failed_images[@]} -gt 0 ]; then
    echo "Failed images:"
    printf '%s\n' "${failed_images[@]}"
fi
