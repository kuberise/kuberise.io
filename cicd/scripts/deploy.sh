KUBECONFIG=$1
REPOSITORY_PASSWORD=$2
ENVIRONMENT=$3

create service account token and ca cert


helm upgrade --install --kube-context $CONTEXT -n argocd -f $VALUES_FILE argocd argocd/argocd --version 3.11.3 --wait

# add project to the argocd server using yaml file
cat <<EOF | kubectl apply --context $CONTEXT -n argocd -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $PROJECT_NAME
  namespace: argocd
spec:
    sourceRepos:
    - '*'
    destinations:
    - namespace: $NAMESPACE
        server: https://kubernetes.default.svc
EOF

# add application to the argocd server using yaml file
kubectl apply --context $CONTEXT -n argocd -f cicd/argocd/application.yaml
