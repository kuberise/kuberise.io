#!/bin/bash

# This script configures Keycloak on the onprem cluster.
# It creates a realm called platform, a user called pgauser, and a client called pgadmin.
CLIENT_SECRET=$1

cat <<EOF > pgadmin_client.json
{
  "clientId": "pgadmin",
  "name": "pgAdmin Client",
  "description": "Provides login for pgAdmin",
  "rootUrl": "https://pgadmin.onprem.kuberise.dev/",
  "adminUrl": "https://pgadmin.onprem.kuberise.dev/",
  "baseUrl": "https://pgadmin.onprem.kuberise.dev/",
  "surrogateAuthRequired": false,
  "enabled": true,
  "alwaysDisplayInConsole": false,
  "clientAuthenticatorType": "client-secret",
  "secret": "$CLIENT_SECRET",
  "redirectUris": [
    "https://pgadmin.onprem.kuberise.dev/*"
  ],
  "webOrigins": [
    "https://pgadmin.onprem.kuberise.dev/"
  ],
  "notBefore": 0,
  "bearerOnly": false,
  "consentRequired": false,
  "standardFlowEnabled": true,
  "implicitFlowEnabled": false,
  "directAccessGrantsEnabled": false,
  "serviceAccountsEnabled": true,
  "publicClient": false,
  "frontchannelLogout": true,
  "protocol": "openid-connect",
  "attributes": {
    "post.logout.redirect.uris": "https://pgadmin.onprem.kuberise.dev/*"
  }
}
EOF


kcadm.sh config credentials --server  https://keycloak.onprem.kuberise.dev --realm master --user admin --password admin
kcadm.sh create realms -s realm=platform -s enabled=true
kcadm.sh create users -r platform -s username=pgauser -s enabled=true -s email=pgauser@kuberise.net -s firstName=PGA -s lastName=User
kcadm.sh set-password -r platform --username pgauser --new-password pgapassword
kcadm.sh create clients -r platform -f pgadmin_client.json

rm -f pgadmin_client.json
