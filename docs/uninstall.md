# Uninstall

If you have a local cluster you can run `minikube delete` or `kind delete cluster` to remove the whole cluster at once. 

If you would like to uninstall the kuberise from your kubernetes you can run this command from kuberise folder 

```bash
export CONTEXT=$(kubectl config current-context)
./scripts/uninstall.sh $CONTEXT local
```
