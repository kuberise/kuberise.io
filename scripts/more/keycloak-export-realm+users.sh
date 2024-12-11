#!/bin/bash
# This script exports the Keycloak realm configuration

kcadm.sh config credentials --server  https://keycloak.onprem.kuberise.dev --realm master --user admin --password admin
kc.sh export --realm platform --users realm_file --dir /Users/mojtaba/repo/github/kuberise/kuberise


quay.io/keycloak/keycloak-operator:19.0.3-legacy
quay.io/keycloak/keycloak-operator:26.0.7
