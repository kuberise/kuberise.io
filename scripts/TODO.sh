

function generate_ca_cert_and_key() {
  local context=$1
  local platform_name=$2

  # Validate platform_name is provided
  if [ -z "$platform_name" ]; then
    echo "platform_name is required as an input parameter."
    return 1
  fi

  # Define the directory and file paths
  DIR=".env/$platform_name"
  CERT="$DIR/ca.crt"
  KEY="$DIR/ca.key"
  CA_BUNDLE="$DIR/ca-bundle.crt"

  # Check if both the certificate and key files exist
  if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
    echo "One or both of the CA certificate/key files do not exist. Generating..."

    # Create the directory structure if it doesn't exist
    mkdir -p "$DIR"

    # Generate the CA certificate and private key
    openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
      -keyout "$KEY" -out "$CERT" -subj "/CN=ca.kuberise.local CA/O=KUBERISE/C=NL"

    echo "CA certificate and key generated."
  else
    echo "CA certificate and key already exist."
  fi

  # Download Let's Encrypt root certificate and create CA bundle
  echo "Creating CA bundle with self-signed and Let's Encrypt certificates..."
  curl -sL https://letsencrypt.org/certs/isrgrootx1.pem > "$DIR/letsencrypt.crt"
  cat "$CERT" "$DIR/letsencrypt.crt" > "$CA_BUNDLE"
  rm "$DIR/letsencrypt.crt"  # Clean up temporary file

  # Create a secret in the cert-manager namespace with the CA certificate
  kubectl create secret tls ca-key-pair-external \
    --cert="$CERT" \
    --key="$KEY" \
    --namespace="cert-manager" \
    --dry-run=client -o yaml | kubectl apply --namespace="cert-manager" --context="$context" -f -

  # List of namespaces to create self-signed CA certificate ConfigMap
  namespaces=("pgadmin" "monitoring" "argocd" "keycloak" "backstage" "postgres" "cert-manager" "external-dns")

  # Iterate over each namespace and create the configmap with the CA bundle
  for namespace in "${namespaces[@]}"; do
    # Create the configmap in the current namespace using the CA bundle
    kubectl create configmap ca-bundle \
      --from-file=ca.crt="$CA_BUNDLE" \
      --namespace="$namespace" \
      --dry-run=client -o yaml | kubectl apply --namespace="$namespace" --context="$context" -f -
  done

  echo "CA bundle created and ConfigMaps updated in all namespaces."
}


function configure_oidc_auth() {
  local context=$1
  local client_secret=$2
  local domain=$3

  echo "Configuring OIDC authentication in kubeconfig..."

  # Get cluster info from current context
  local cluster_name=$(kubectl config view -o jsonpath="{.contexts[?(@.name == \"$context\")].context.cluster}")

  # Add/Update oidc user
  kubectl config set-credentials oidc \
    --exec-api-version=client.authentication.k8s.io/v1beta1 \
    --exec-command=kubectl \
    --exec-arg=oidc-login \
    --exec-arg=get-token \
    --exec-arg=--oidc-issuer-url=https://keycloak.$domain/realms/platform \
    --exec-arg=--oidc-client-id=kubernetes \
    --exec-arg=--oidc-client-secret=$client_secret

  # Add/Update oidc context using the same cluster as original context
  kubectl config set-context oidc \
    --cluster=$cluster_name \
    --user=oidc \
    --namespace=default

  echo "OIDC authentication configured. Use 'kubectl config use-context oidc' to switch to OIDC authentication."
}

ARGOCD_CLIENT_SECRET=$(echo -n 'YqNdS8SBbI2iNPV0zs0LpUstTfy5iXKY' | base64)
kubectl patch secret argocd-secret -n $NAMESPACE_ARGOCD --patch "
data:
  oidc.keycloak.clientSecret: $ARGOCD_CLIENT_SECRET
"

# Get the client secret from the kubernetes-oauth2-client-secret
CLIENT_SECRET=$(kubectl get secret kubernetes-oauth2-client-secret -n keycloak -o jsonpath='{.data.client-secret}' | base64 -d)
configure_oidc_auth "$CONTEXT" "$CLIENT_SECRET" "$DOMAIN"
