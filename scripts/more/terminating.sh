#!/bin/bash

# Get all namespaces in Terminating status
terminating_namespaces=$(kubectl get namespaces --field-selector=status.phase=Terminating -o jsonpath='{.items[*].metadata.name}')

# Delete all namespaces in Terminating status
for ns in $terminating_namespaces; do
  echo "Deleting namespace: $ns"
  kubectl get namespace $ns -o json | \
  jq '.spec.finalizers=[]' | \
  kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f -
done
