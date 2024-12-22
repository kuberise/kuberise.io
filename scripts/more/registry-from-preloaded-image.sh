#!/bin/bash

# Enable command echoing
set -x

# Define network name
NETWORK="platform"

##### ---- start clean
docker stop registry > /dev/null 2>&1
docker rm registry > /dev/null 2>&1
docker network rm $NETWORK > /dev/null 2>&1
##### ----

# Create network with subnet configuration
docker network create --subnet=172.20.0.0/16 $NETWORK

docker run -d \
  --name registry \
  --net $NETWORK \
  -v ~/.registry/certs:/certs \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
  -p 5001:5000 \
  registry-with-images:latest

docker pull localhost:5001/nginx
