#!/bin/bash



function delete_secret() {
  local context=$1
  local namespace=$2
  local secret_name=$3
  echo "Deleting secret: $secret_name in namespace: $namespace"
  kubectl delete secret "$secret_name" --context "$context" -n "$namespace"
}

function delete_namespace() {
  local context=$1
  local namespace=$2
  echo "Deleting namespace: $namespace in context: $context"
  kubectl delete namespace "$namespace" --context "$context"
}

function uninstall_argocd() {
  local context=$1
  local namespace=$2
  echo "Uninstalling ArgoCD using Helm..."
  helm uninstall argocd --kube-context "$context" -n "$namespace"
}


CONTEXT=${1-}
CLUSTER_NAME=${2}

# context MUST be set to connect to the k8s cluster
if [ -z "${CONTEXT}" ]
then
  echo 1>&2 CONTEXT is undefined
  exit 2
fi

if [ -z "${CLUSTER_NAME}" ]
then
  echo 1>&2 CLUSTER_NAME is undefined
  exit 2
fi

# skip deleting the "cert-manager" namespace to keep the certificates and avoid issuing many times.
namespaces=("argocd" "cloudnative-pg" "keycloak" "backstage" "ingress-nginx-internal" "ingress-nginx-external" "monitoring" "ingresses" "gitea" "frontend-https" "metallb" "raw" "show-env" "external-dns" "internal-dns" "backend" "metrics-server")

# Convert the array to a string with each namespace on a new line
namespaces_str=$(IFS=$'\n'; echo "${namespaces[*]}")

# Prompt for confirmation
read -p "This script will remove the '$CLUSTER_NAME' cluster from the '$CONTEXT' Kubernetes context. It will also delete the following namespaces:

$namespaces_str

Are you sure you want to continue? (yes/no): " answer

# Check if the answer is "yes"
if [ "$answer" != "yes" ]; then
  echo "Aborting uninstallation."
  exit 0
fi

# Continue with uninstallation
# namespace
NAMESPACE=argocd
kubectl delete --context $CONTEXT -n $NAMESPACE application app-of-apps-$CLUSTER_NAME > /dev/null 2>&1
kubectl delete --context $CONTEXT -n $NAMESPACE appproject $CLUSTER_NAME > /dev/null 2>&1

helm uninstall argocd -n argocd --kube-context $CONTEXT -n $NAMESPACE > /dev/null 2>&1

for namespace in "${namespaces[@]}"
do
  echo "Deleting namespace: $namespace"
  kubectl delete namespace "$namespace" --context "$CONTEXT" > /dev/null 2>&1
done


# kubectl get namespaces --context $CONTEXT --no-headers -o custom-columns=":metadata.name" | grep -vE '^(default|kube-system|kube-public|kube-node-lease)$' | xargs -r kubectl delete namespace
# kubectl delete pv --all --context $CONTEXT

echo "kuberise uninstalled successfully."
