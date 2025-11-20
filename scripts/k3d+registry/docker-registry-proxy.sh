#!/bin/bash

mkdir ~/docker_registry_proxy > /dev/null 2>&1
docker run --name registry-proxy --rm -it --network kuberise -p 0.0.0.0:3128:3128 -d \
  -v ~/docker_registry_proxy/mirror_cache:/docker_mirror_cache \
  -v ~/docker_registry_proxy/certs:/ca \
  -e ENABLE_MANIFEST_CACHE=true \
  -e REGISTRIES="registry.k8s.io gcr.io quay.io ghcr.io public.ecr.aws" \
  -e VERIFY_SSL=false \
  rpardini/docker-registry-proxy:0.6.5 > /dev/null 2>&1
