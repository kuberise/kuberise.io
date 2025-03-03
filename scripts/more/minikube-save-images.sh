#!/bin/bash
#
# Script: minikube-save-images.sh
#
# Description:
# This script saves all Docker images available in the Minikube Docker daemon to tar files
# in a specified output directory. It connects to the Minikube Docker daemon, retrieves a list
# of unique image repositories, and saves each one as a tar file. The operations run in parallel
# to speed up the process, with the script waiting for all save operations to complete before exiting.
#
# The tar files are named based on the repository name (with slashes replaced by underscores)
# and are saved to the directory specified in the OUTPUT_DIR variable (defaults to ~/tmp/docker_images).
#
# Usage:
# ./minikube-save-images.sh
#

# Point your shell to minikube's docker-daemon
eval $(minikube docker-env)

# Define output directory as a variable
OUTPUT_DIR=~/tmp/docker_images

# Create the specified directory
mkdir -p $OUTPUT_DIR

# Array to keep track of background processes
pids=()

# Loop through unique image repositories (without tags)
for image in $(docker images --format "{{.Repository}}" | sort -u); do
  # Create a safe filename by replacing slashes
  safe_name=$(echo $image | tr '/' '_')
  echo "Starting save of $image to $OUTPUT_DIR/$safe_name.tar"

  # Run docker save in background
  docker save -o "$OUTPUT_DIR/$safe_name.tar" "$image" &

  # Store the process ID
  pids+=($!)
done

# Wait for all background processes to complete
echo "Waiting for all save operations to complete..."
for pid in "${pids[@]}"; do
  wait $pid
  echo "Process $pid completed"
done

echo "All images have been saved to $OUTPUT_DIR directory"
