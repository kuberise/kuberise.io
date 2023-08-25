#!/bin/bash 

set -euo pipefail

CONTEXT=${1-}               # example: minikube-dta
ENVIRONMENT=${2-dta}        # example: dta or prd (defaults to dta)

# context MUST be set to connect to the k8s cluster
if [ -z "${CONTEXT}" ]
then 
  echo 1>&2 CONTEXT is undefined
  exit 2
fi

# namespace 
NAMESPACE=argocd
PROJECT_NAME=platform-$ENVIRONMENT


kubectl delete --context $CONTEXT -n $NAMESPACE -f cicd/argocd/app-of-apps-$ENVIRONMENT.yaml

cat <<EOF | kubectl delete --context $CONTEXT -n $NAMESPACE -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $PROJECT_NAME
  namespace: $NAMESPACE
  # Finalizer that ensures that project is not deleted until it is not referenced by any application
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  sourceRepos:
  - '*'
  destinations:
  - name: '*'
    namespace: '*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF
