#!/bin/bash

# This script demonstrates how to configure pgAdmin to use Keycloak for authentication in http mode and in local mode.

CLIENT_SECRET=$(openssl rand -hex 16)
REALM=platform
NETWORK=privnet
CLIENT_ID=pgadmin # this is different from CLIENT_UUID


cat <<EOF > config_local.py
import os
import logging

FILE_LOG_LEVEL = logging.INFO
SERVER_MODE = True
CONSOLE_LOG_LEVEL = logging.INFO
MASTER_PASSWORD_REQUIRED = True
AUTHENTICATION_SOURCES = ['internal', 'oauth2']
OAUTH2_CONFIG = [
  {
    'OAUTH2_NAME': 'Keycloak',
    'OAUTH2_DISPLAY_NAME': 'Keycloak',
    'OAUTH2_CLIENT_ID': '$CLIENT_ID',
    'OAUTH2_CLIENT_SECRET': '$CLIENT_SECRET',
    'OAUTH2_TOKEN_URL': 'http://keycloak:8080/realms/$REALM/protocol/openid-connect/token',
    'OAUTH2_AUTHORIZATION_URL': 'http://keycloak:8080/realms/$REALM/protocol/openid-connect/auth',
    'OAUTH2_SERVER_METADATA_URL': 'http://keycloak:8080/realms/$REALM/.well-known/openid-configuration',
    'OAUTH2_API_BASE_URL': 'http://keycloak:8080/',
    'OAUTH2_USERINFO_ENDPOINT': 'http://keycloak:8080/realms/$REALM/protocol/openid-connect/userinfo',
    'OAUTH2_SCOPE': 'openid email profile',
    'OAUTH2_USERNAME_CLAIM': 'preferred_username',
    'OAUTH2_LOGOUT_URL': 'http://keycloak:8080/realms/$REALM/protocol/openid-connect/logout?id_token_hint={id_token}&client_id={$CLIENT_ID}',
    'OAUTH2_ICON': 'fa-solid fa-unlock',
    'OAUTH2_BUTTON_COLOR': '#f44242',
    'OAUTH2_SSL_CERT_VERIFICATION': False, # for self-signed certificates it should be False
  }
]
EOF


docker network create $NETWORK  > /dev/null || true


echo "Starting postgres ... "
docker run --rm -d --name postgres --network $NETWORK -e POSTGRES_USER=keycloak -e POSTGRES_PASSWORD=keycloak -e POSTGRES_DB=db -p 5432:5432 postgres:15 > /dev/null
sleep 5

echo "Starting keycloak ... "
docker run --rm -d --name keycloak --network $NETWORK \
  -p 8080:8080 \
  -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://postgres:5432/db \
  -e KC_DB_USERNAME=keycloak -e KC_DB_PASSWORD=keycloak \
  -e KC_HTTP_ENABLED=true \
  -e KC_HOSTNAME=keycloak \
  -e KEYCLOAK_HOSTNAME_STRICT=false \
  quay.io/keycloak/keycloak:26.0 start-dev --http-enabled=true > /dev/null
sleep 10

# realm login page: http://localhost:8080/admin/$REALM/console/

echo "Configuring keycloak ... "
# create new realm, client and user
kcadm.sh config credentials --server  http://localhost:8080 --realm master --user admin --password admin
kcadm.sh create realms -s realm=$REALM -s enabled=true
USER_ID=$(kcadm.sh create users -r $REALM -s username=pgauser -s enabled=true -s email=pgauser@kuberise.net -s firstName=PGA -s lastName=User -i)
echo User ID: $USER_ID
kcadm.sh set-password -r $REALM --username pgauser --new-password pgapassword
CLIENT_UUID=$(kcadm.sh create clients -r $REALM \
  -s clientId=$CLIENT_ID \
  -s enabled=true \
  -s secret=$CLIENT_SECRET \
  -s 'redirectUris=["http://pgadmin/*"]' \
  -s publicClient=false \
  -s protocol=openid-connect \
  -s baseUrl="http://pgadmin" \
  -s directAccessGrantsEnabled=true \
  -s standardFlowEnabled=true \
  -s implicitFlowEnabled=false \
  -s serviceAccountsEnabled=true \
  -s authorizationServicesEnabled=false \
  -i)
echo Client UUID: $CLIENT_UUID

# Get service account user ID
SERVICE_ACCOUNT_USER_ID=$(kcadm.sh get clients/$CLIENT_UUID/service-account-user -r $REALM | grep "\"id\"" | cut -d'"' -f4)

# Add roles
kcadm.sh add-roles -r $REALM \
  --uid $SERVICE_ACCOUNT_USER_ID \
  --cclientid realm-management \
  --rolename view-users \
  --rolename manage-users

echo "Starting $CLIENT_ID ... "
# run pgadmin
docker run --rm -d --name $CLIENT_ID --network $NETWORK \
  -p 5050:80 \
  -e PGADMIN_DEFAULT_EMAIL="admin@admin.com" \
  -e PGADMIN_DEFAULT_PASSWORD="admin" \
  -e PGADMIN_CONFIG_CONSOLE_LOG_LEVEL=10 \
  -v $(pwd)/config_local.py:/pgadmin4/config_local.py \
  dpage/pgadmin4 > /dev/null

sleep 3

# try sso in a firefox that is inside the same network as keycloak
# open the pgadmin URL by default and use persistent configuration of firefox (optional)
# open default URL in firefox:   -e FF_OPEN_URL=pgadmin \
docker run -it --rm -d --name firefox-browser --network $NETWORK \
  -v ~/docker/firefox:/config:rw \
  -p 5800:5800 jlesage/firefox > /dev/null

echo "pgAdmin dashboard: http://pgadmin"
echo "Keycloak dashboard:  http://keycloak:8080"
echo
echo "To clean up the demo, just close the firefox browser."
sleep 3

# Open the URL in Firefox
open -a "Firefox" http://localhost:5800



# Wait until the tab is closed
while pgrep -x "firefox" > /dev/null; do sleep 1; done


# Cleanup

echo "Cleaning up ... "

echo "Closing all open sessions..." # to demonstrate the logout functionality

# Get access token using client credentials
TOKEN_RESPONSE=$(curl -s -X POST \
  "http://localhost:8080/realms/$REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

# Get all sessions for the user
SESSIONS=$(curl -s -X GET \
  "http://localhost:8080/admin/realms/$REALM/users/$USER_ID/sessions" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

# Extract session IDs and delete each session
echo $SESSIONS | jq -r '.[] | .id' | while read -r SESSION_ID; do
  curl -s -X DELETE \
    "http://localhost:8080/admin/realms/$REALM/sessions/$SESSION_ID" \
    -H "Authorization: Bearer $ACCESS_TOKEN"
  echo "Deleted session: $SESSION_ID"
done


rm -f config_local.py
docker stop firefox-browser
docker stop postgres
docker stop keycloak
docker stop pgadmin
docker network rm $NETWORK
