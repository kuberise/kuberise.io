#!/bin/bash
# This script exports the Keycloak realm configuration

kcadm.sh config credentials --server  https://keycloak.onprem.kuberise.dev --realm master --user admin --password admin
kc.sh export --realm testrealm --users same_file --file testrealm.json
