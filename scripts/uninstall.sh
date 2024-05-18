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
PLATFORM_NAME=${2}

# context MUST be set to connect to the k8s cluster
if [ -z "${CONTEXT}" ]
then
  echo 1>&2 CONTEXT is undefined
  exit 2
fi

if [ -z "${PLATFORM_NAME}" ]
then
  echo 1>&2 PLATFORM_NAME is undefined
  exit 2
fi

# namespace
NAMESPACE=argocd
kubectl delete --context $CONTEXT -n $NAMESPACE application app-of-apps-$PLATFORM_NAME
kubectl delete --context $CONTEXT -n $NAMESPACE appproject $PLATFORM_NAME
helm uninstall argocd -n argocd --kube-context $CONTEXT -n $NAMESPACE

namespaces=("argocd" "cloudnative-pg" "keycloak" "backstage" "ingress-nginx" "monitoring")
for namespace in "${namespaces[@]}"
do
  echo "Deleting namespace: $namespace"
  kubectl delete namespace "$namespace" --context "$CONTEXT"
done


# kubectl get namespaces --context $CONTEXT --no-headers -o custom-columns=":metadata.name" | grep -vE '^(default|kube-system|kube-public|kube-node-lease)$' | xargs -r kubectl delete namespace
# kubectl delete pv --all --context $CONTEXT

echo "kuberise uninstalled successfully."
