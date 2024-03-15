git checkout gh-pages
git merge main

helm package charts/kuberise/
helm repo index . --url https://kuberise.github.io/kuberise/


helm repo add kuberise https://kuberise.github.io/kuberise/
helm repo update
