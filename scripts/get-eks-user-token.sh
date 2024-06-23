#!/bin/bash

aws eks get-token --cluster-name dev-eksdemo | yq .status.token

# in kubeconfig file:
# users:
# - name: arn:aws:eks:eu-central-1:011369383313:cluster/dev-eksdemo
#   user:
#     token: k8s-aws-v1.aHR0cHM6
