# Kuberise Hands-on Workshop #1

The goal is to create an internal developer platform (IDP) in a local kubernetes cluster (minikube or KIND) and deploy a microservice into this platform.

## Step 1 - Slack and Miro

- Join #kuberise slack channel
- Join the miro board (link in slack channel)

## Step 2 - Install a local kubernetes

- Install minikube or KIND in your laptop
- Other tools you need: kubectl, helm, git, docker
- Create a local kubernetes cluster
- Check if you have access to the cluster by running a kubectl command
- Write a feedback in miro about this step

## Step 3

- Make a fork from the repository in your github account and follow the instruction [here](../../README.md) and do a full installation of kuberise in your local cluster.
- Run `sudo minikube tunnel` for minikube to run a local tunnel to your kubernetes node
- or run `sudo cloud-provider-kind` for kind to run a local tunnel to your kubernetes node
- Try to open the ingress address of different services:

  Platform Services:
  - [argocd-172-19-0-3.nip.io](http://argocd-172-19-0-3.nip.io)
  - [keycloak-172-19-0-3.nip.io](http://keycloak-172-19-0-3.nip.io)
  - [grafana-172-19-0-3.nip.io](http://grafana-172-19-0-3.nip.io)
  - [prometheus-172-19-0-3.nip.io](http://prometheus-172-19-0-3.nip.io)
  - [backstage-172-19-0-3.nip.io](http://backstage-172-19-0-3.nip.io)

  Application microservices:
  - [frontend.dev-172-19-0-3.nip.io](http://frontend.dev-172-19-0-3.nip.io)
  - [frontend.tst-172-19-0-3.nip.io](http://frontend.tst-172-19-0-3.nip.io)
  - [frontend-172-19-0-3.nip.io](http://frontend-172-19-0-3.nip.io)
  - [show-env.dev-172-19-0-3.nip.io](http://show-env.dev-172-19-0-3.nip.io)

- Check grafana node exporter dashboard about your kubernetes metrics and resources
- How was your experience of installing kuberise? Write a feedback in miro board.

## Step 4

- Fork repo https://github.com/kuberise/show-env
- Add your docker hub credentials to the secrets of the repo
- Run Actions pipeline to build and push to your docker hub.
- Add your microservice to your kuberise platform
- Add a version tag to a commit and deploy that tag to the production environment (namespace)
- Check logs of your microservice in loki using grafana dashboard
- How was your experience of deploying a microservice in kubernetes using kuberise? Write a feedback in miro board about it.
