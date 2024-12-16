#!/bin/bash

# Array of images
declare -a images=(
    "registry.k8s.io/etcd:3.5.15-0"
    "registry.k8s.io/pause:3.10"
    "registry.k8s.io/kube-controller-manager:v1.31.0"
    "registry.k8s.io/coredns/coredns:v1.11.1"
    "registry.k8s.io/kube-scheduler:v1.31.0"
    "gcr.io/k8s-minikube/storage-provisioner:v5"
    "registry.k8s.io/kube-apiserver:v1.31.0"
    "registry.k8s.io/kube-proxy:v1.31.0"
    "gcr.io/k8s-minikube/kicbase:v0.0.45"
    "public.ecr.aws/docker/library/redis:7.2.4-alpine"
    "ghcr.io/kuberise/show-env"
    "docker.io/library/nginx:alpine"
    "docker.io/dpage/pgadmin4:8.13"
    "docker.io/bitnami/external-dns:0.15.0-debian-12-r6"
    "docker.io/epamedp/keycloak-operator:1.23.0"
    "quay.io/argoprojlabs/argocd-image-updater:v0.15.0"
    "docker.io/grafana/grafana:11.3.0"
    "quay.io/prometheus/prometheus:v2.55.0"
    "quay.io/prometheus-operator/prometheus-config-reloader:v0.77.2"
    "quay.io/prometheus-operator/prometheus-operator:v0.77.2"
    "registry.k8s.io/ingress-nginx/controller:v1.12.0-beta.0"
    "registry.k8s.io/ingress-nginx/kube-webhook-certgen:v20221220-controller-v1.5.1-58-g787ea74b6"
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
    "ghcr.io/kuberise/show-env:latest"
    "ghcr.io/cloudnative-pg/cloudnative-pg:1.22.1"
    "ghcr.io/dexidp/dex:v2.38.0"
    "quay.io/frrouting/frr:9.1.0"
    "docker.io/nginxinc/nginx-unprivileged:1.20.2-alpine"
    "docker.io/library/nginx:1.16.0"
    "registry.k8s.io/coredns/coredns:v1.11.1"
    "registry.k8s.io/etcd:3.5.15-0"
    "registry.k8s.io/kube-apiserver:v1.31.0"
    "registry.k8s.io/kube-controller-manager:v1.31.0"
    "registry.k8s.io/kube-proxy:v1.31.0"
    "registry.k8s.io/kube-scheduler:v1.31.0"
    "gcr.io/k8s-minikube/storage-provisioner:v5"
)

NEW_REGISTRY="localhost:5001"

# Function to process an image
process_image() {
    local image=$1
    echo "Processing image: $image"

    # Extract image name without registry and tag
    local image_name=$(echo "$image" | sed -E 's|^[^/]+/||')
    local new_image="$NEW_REGISTRY/$image_name"

    echo "Pulling $image"
    if ! docker pull "$image"; then
        echo "Failed to pull $image"
        return 1
    fi

    echo "Tagging $image as $new_image"
    if ! docker tag "$image" "$new_image"; then
        echo "Failed to tag $image"
        return 1
    fi

    echo "Pushing $new_image"
    if ! docker push "$new_image"; then
        echo "Failed to push $new_image"
        return 1
    fi

    echo "Successfully processed $image"
    return 0
}

# Counters for statistics
total_images=${#images[@]}
success_count=0
failed_count=0
failed_images=()

# Process each image
current_image=0

for image in "${images[@]}"; do
    ((current_image++))
    echo "[$current_image/$total_images] Processing $image"

    if process_image "$image"; then
        ((success_count++))
    else
        ((failed_count++))
        failed_images+=("$image")
    fi
    echo "----------------------------------------"
done

# Print summary
echo "Processing Summary:"
echo "Total images: $total_images"
echo "Successfully processed: $success_count"
echo "Failed to process: $failed_count"

if [ ${#failed_images[@]} -gt 0 ]; then
    echo "Failed images:"
    printf '%s\n' "${failed_images[@]}"
fi


# Remove old registry image if it exists
docker rmi registry-with-images:latest || true
# Commit the registry container with its contents to a new image
docker commit registry registry-with-images:latest
