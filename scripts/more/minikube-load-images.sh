#!/bin/bash
#
# Script: minikube-load-images.sh
#
# Description:
# This script loads Docker images from tar files into the Minikube Docker daemon.
# It connects to the Minikube Docker daemon, finds all .tar files in the specified source
# directory, and loads each one into the Docker daemon. Operations run in parallel to
# speed up the process, with the script waiting for all load operations to complete before exiting.
#
# This script complements minikube-save-images.sh, which can be used to save images first.
#
# Usage:
# ./minikube-load-images.sh
#

# Point your shell to minikube's docker-daemon
eval $(minikube docker-env)

# Define source directory as a variable (defaults to ~/tmp/docker_images)
SOURCE_DIR=~/tmp/docker_images

# Check if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist!"
  exit 1
fi

# Array to keep track of background processes
pids=()

# Find all .tar files in the source directory
echo "Looking for Docker image tar files in $SOURCE_DIR"
for tar_file in "$SOURCE_DIR"/*.tar; do
  # Skip if no files are found
  if [ ! -f "$tar_file" ]; then
    echo "No tar files found in $SOURCE_DIR"
    break
  fi

  # Get base name of the file for display
  base_name=$(basename "$tar_file")
  echo "Starting load of $base_name into Minikube Docker daemon"

  # Run docker load in background
  docker load -i "$tar_file" &

  # Store the process ID
  pids+=($!)
done

# Wait for all background processes to complete
if [ ${#pids[@]} -gt 0 ]; then
  echo "Waiting for all load operations to complete..."
  for pid in "${pids[@]}"; do
    wait $pid
    echo "Process $pid completed"
  done
  echo "All images have been loaded into the Minikube Docker daemon"
else
  echo "No images were loaded"
fi
