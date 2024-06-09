# Minikube

Minikube is a tool to install a light kubernetes cluster in you local computer.

After deploying to a minikube local cluster, you can run `sudo minikube tunnel` command to use the local ingress to access services. For example to go to argocd and keycloak and grafana you can use these urls and you don't need to do port-forward:

- [argocd-172-19-0-3.nip.io](argocd-172-19-0-3.nip.io)
- [grafana-172-19-0-3.nip.io](grafana-172-19-0-3.nip.io)
- [http://keycloak-172-19-0-3.nip.io](http://keycloak-172-19-0-3.nip.io)

In default minikube configuration, all services admin username and passwords are admin.
For minikube tunnel to work, the minikube config information should be in ~/.kube/config file which is the default kubeconfig location.

If you can not use minikube tunnel, you can use port-forward to be able to access the dashboard of different services:

```sh
kubectl port-forward svc/argocd-server -n argocd 8081:80 &
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 8082:80 &
kubectl  port-forward svc/keycloak -n keycloak 8083:80 &
```

- ArgoCD dashboard: [http://localhost:8081](http://localhost:8081)
- Grafana dashboard: [http://localhost:8082](http://localhost:8082)
- Keycloak dashboard: [http://localhost:8083](http://localhost:8083)
