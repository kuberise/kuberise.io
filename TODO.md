
- [ ] read db host and user/pass from secrets in todolist app
- [ ] read pgadmin client secret from secrets
- [ ] docs:

## docs: how to create a service

how to create a service:
- app-of-apps/values.yaml
- app-of-apps/values-platformName.yaml
- value.yaml in values default folder
- value.yaml in values folder
- ingress in values/platformName/platform/ingresses/values.yaml
- certificate in values/platformName/platform/cert-manager/values.yaml


## External-dns error in minikube

The error message you've provided indicates that ExternalDNS is failing to connect to an etcd endpoint:

```
Error while dialing: dial tcp: lookup etcd-extdns on 10.96.0.10:53: no such host
```

This occurs because when using the coredns provider, ExternalDNS expects CoreDNS to be configured with an etcd backend, which is not the default setup in Kubernetes clusters like Minikube. By default, CoreDNS in Kubernetes uses a file-based configuration and does not use etcd.
