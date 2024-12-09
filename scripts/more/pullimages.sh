#!/bin/bash

# Whenever you start a minikube cluster and deploy kuberise, it will pull all images again.
# Once you deployed kuberise and make sure all required images are inside minikube node,
# you can run this command to save all pulled docker images in you local file system,
# then next time you can start a new minikube cluster by loading this file and
# it will not pull those images again and deploying kuberise will be much faster.

# Archive all images inside minikube node to one tar file.
minikube ssh -- 'docker save $(docker images -q) -o /tmp/all_docker_images.tar'

# Copy that file from minikube node to local file system.
minikube cp minikube:/tmp/all_docker_images.tar ~/tmp/all_docker_images.tar

# Create a new minikube cluster called minikube2
minikube start --memory=max --cpus=max -p minikube2

# Load all docker images to minikube2
minikube -p minikube2 image load ~/tmp/all_docker_images.tar
