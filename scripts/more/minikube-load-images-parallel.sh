#!/bin/bash

# Exit on error
set -e

# This script loads Docker images into the minikube cluster in parallel

# Maximum number of concurrent image loads
MAX_PARALLEL=8

# Function to check if minikube is running
check_minikube_status() {
    if ! minikube status -p minikube | grep -q "Running"; then
        echo "Error: Minikube is not running. Please start minikube first."
        exit 1
    fi
}

# Function to check if Docker is running
check_docker_status() {
    if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker is not running. Please start Docker first."
        exit 1
    fi
}

# Configure shell to use minikube's Docker daemon
setup_minikube_docker() {
    echo "Configuring Docker environment for minikube..."
    eval $(minikube -p minikube docker-env) || {
        echo "Error: Failed to configure Docker environment for minikube"
        exit 1
    }
}

# Function to load a single image and track its status
load_image() {
    local image=$1
    local index=$2
    local total=$3

    echo "[$index/$total] Loading image: $image"
    if minikube -p minikube image load "$image" --daemon > /dev/null 2>&1; then
        echo "[$index/$total] ✓ Successfully loaded: $image"
        return 0
    else
        echo "[$index/$total] ✗ Failed to load: $image"
        return 1
    fi
}

# Define array with all Docker images
images=(
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

main() {
    # Perform initial checks
    check_minikube_status
    check_docker_status
    setup_minikube_docker

    total_images=${#images[@]}
    echo "Starting to load $total_images images with max $MAX_PARALLEL parallel processes..."

    # Array to store background process PIDs
    pids=()
    failed_images=()

    # Process all images
    for i in "${!images[@]}"; do
        # If we've reached max parallel processes, wait for one to finish
        while [ ${#pids[@]} -ge $MAX_PARALLEL ]; do
            for j in "${!pids[@]}"; do
                if ! kill -0 ${pids[j]} 2>/dev/null; then
                    wait ${pids[j]}
                    exit_status=$?
                    if [ $exit_status -ne 0 ]; then
                        failed_images+=("${images[j]}")
                    fi
                    unset 'pids[j]'
                fi
            done
            sleep 0.1
        done

        # Start new background process
        load_image "${images[i]}" "$((i+1))" "$total_images" &
        pids+=($!)
    done

    # Wait for remaining processes to finish
    for pid in "${pids[@]}"; do
        wait $pid
        exit_status=$?
        if [ $exit_status -ne 0 ]; then
            failed_images+=("${images[i]}")
        fi
    done

    echo "Image loading process completed."

    # Report any failures
    if [ ${#failed_images[@]} -gt 0 ]; then
        echo "The following images failed to load:"
        printf '%s\n' "${failed_images[@]}"
        exit 1
    fi
}

# Run the main function
main
