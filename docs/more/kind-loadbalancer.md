# How to enable ingress in kind cluster

To be able to use ingress in kind local cluster, one way is to use Cloud Provider Kind. You have to run it in a terminal with sudo permission and keep it open. Then an external IP will be assigned to the loadbalancer services inside the kind cluster.

More details:
- [Kubernetes Cloud Provider for KIND](https://github.com/kubernetes-sigs/cloud-provider-kind)
- [LoadBalancer in KIND](https://kind.sigs.k8s.io/docs/user/loadbalancer/)
