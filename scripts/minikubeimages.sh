#!/bin/bash

# Function to save images from the current Minikube cluster
save_images() {
  local profile=$1
  echo "Saving Docker images from Minikube..."
  minikube -p $profile ssh -- "docker save -o images.tar \$(docker images -q)"
  minikube -p $profile cp $profile:/home/docker/images.tar images.tar
}

# Function to load images into a new Minikube cluster
load_images() {
  local profile=$1
  echo "Loading Docker images into new Minikube..."
  minikube -p $profile cp images.tar $profile:/home/docker/images.tar
  minikube -p $profile ssh -- "docker load -i images.tar"
}

# Main script execution
if [ "$1" == "save" ]; then
  save_images $2
elif [ "$1" == "load" ]; then
  load_images $2
else
  echo "Usage: $0 {save|load}"
fi

# Usage:
# $ ./scripts/minikubeimages.sh save minikube1
# $ ./scripts/minikubeimages.sh load minikube2
#
# This script saves all the Docker images from the Minikube cluster named minikube1
# and loads them into a new Minikube cluster named minikube2.
