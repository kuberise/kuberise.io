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
    'OAUTH2_CLIENT_ID': 'pgadmin',
    'OAUTH2_CLIENT_SECRET': '7fbf85fdd0c884d0cc845355fbbe00f4',
    'OAUTH2_TOKEN_URL': 'http://keycloak:8080/realms/platform/protocol/openid-connect/token',
    'OAUTH2_AUTHORIZATION_URL': 'http://keycloak:8080/realms/platform/protocol/openid-connect/auth',
    'OAUTH2_SERVER_METADATA_URL': 'http://keycloak:8080/realms/platform/.well-known/openid-configuration',
    'OAUTH2_API_BASE_URL': 'http://keycloak:8080/',
    'OAUTH2_USERINFO_ENDPOINT': 'http://keycloak:8080/realms/platform/protocol/openid-connect/userinfo',
    'OAUTH2_SCOPE': 'openid email profile',
    'OAUTH2_USERNAME_CLAIM': 'preferred_username',
    'OAUTH2_LOGOUT_URL': 'http://keycloak:8080/realms/platform/protocol/openid-connect/logout?id_token_hint={id_token}&client_id={pgadmin}',
    'OAUTH2_ICON': 'fa-solid fa-unlock',
    'OAUTH2_BUTTON_COLOR': '#f44242',
    'OAUTH2_SSL_CERT_VERIFICATION': False, # for self-signed certificates it should be False
  }
]
