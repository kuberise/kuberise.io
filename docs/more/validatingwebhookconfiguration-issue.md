# Apply ingress rule error after install ingress-nginx: x509 certificate is not valid ingress-nginx-controller-admission.ingress-nginx.svc

Fix for the issue without deleting the validatingwebhookconfigurations.
```
CA=$(kubectl -n ingress-nginx get secret ingress-nginx-admission -ojsonpath='{.data.ca}')
kubectl patch validatingwebhookconfigurations ingress-nginx-admission --type='json' -p='[{"op": "add", "path": "/webhooks/0/clientConfig/caBundle", "value":"'$CA'"}]'
```

---

I had a similar issue with missing caBundle in the validatingwebhookconfigurations/ingress-nginx-admission, and it was installed via ArgoCD and a customized ingress-nginx helm chart.

Since ingress-nginx-admission-patch has an annotation "helm.sh/hook": post-install, caBundle will only appear in the validatingwebhookconfigurations after the Chart is fully installed.

In my case, my custom chart contains some resources that required the admission webhook with the caBundle, and that caused Helm chart to never reaches the 'post-install' stage.

My solution is to add the annotation "helm.sh/hook": post-install to my custom resource as well.




[link](https://github.com/kubernetes/ingress-nginx/issues/5968)
