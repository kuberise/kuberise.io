#! /bin/bash

AZURE_DNS_ZONE_RESOURCE_GROUP="kuberise" # name of resource group where dns zone is hosted
AZURE_DNS_ZONE="kuberise.internal" # DNS zone name like kuberise.internal or sub.kuberise.internal
AZURE_AKS_RESOURCE_GROUP="kuberise" # name of resource group where aks cluster was created
AZURE_AKS_CLUSTER_NAME="prd-kuberise" # name of aks cluster previously created
LOCATION="northeurope"
AKS_VNET="main"

# create a Azure DNS zone
az network private-dns zone create --resource-group "$AZURE_DNS_ZONE_RESOURCE_GROUP" --name "$AZURE_DNS_ZONE"
az account show --query "tenantId"
az account show --query "id"

# create a virtual network link to the DNS zone
az network private-dns link vnet create --resource-group "$AZURE_DNS_ZONE_RESOURCE_GROUP" \
--zone-name "$AZURE_DNS_ZONE" --name "$AZURE_DNS_ZONE" --virtual-network "$AKS_VNET" --registration-enabled false

# create a secret containing the configuration file called azure.json
# {
#   "tenantId": "01234abc-de56-ff78-abc1-234567890def",
#   "subscriptionId": "01234abc-de56-ff78-abc1-234567890def",
#   "resourceGroup": "MyDnsResourceGroup",
#   "aadClientId": "01234abc-de56-ff78-abc1-234567890def",
#   "useWorkloadIdentityExtension": true
# }
# ExternalDNS expects, by default, that the configuration file is at /etc/kubernetes/azure.json

# Update your cluster to install OIDC Issuer and Workload Identity
az aks update --resource-group ${AZURE_AKS_RESOURCE_GROUP} --name ${AZURE_AKS_CLUSTER_NAME} --enable-oidc-issuer --enable-workload-identity

# create a managed identity
IDENTITY_RESOURCE_GROUP=$AZURE_AKS_RESOURCE_GROUP # custom group or reuse AKS group
IDENTITY_NAME="kuberise-internal-identity"
az identity create --resource-group "${IDENTITY_RESOURCE_GROUP}" --name "${IDENTITY_NAME}"

# fetch identity client id from managed identity created earlier
IDENTITY_CLIENT_ID=$(az identity show --resource-group "${IDENTITY_RESOURCE_GROUP}" \
  --name "${IDENTITY_NAME}" --query "clientId" --output tsv)

# fetch DNS id used to grant access to the managed identity
DNS_ID=$(az network private-dns zone show --name "${AZURE_DNS_ZONE}" \
  --resource-group "${AZURE_DNS_ZONE_RESOURCE_GROUP}" --query "id" --output tsv)
RESOURCE_GROUP_ID=$(az group show --name "${AZURE_DNS_ZONE_RESOURCE_GROUP}" --query "id" --output tsv)

# Grant access to Azure PRIVATE-DNS zone for the managed identity:
az role assignment create --role "Private DNS Zone Contributor" \
  --assignee "${IDENTITY_CLIENT_ID}" --scope "${DNS_ID}"
az role assignment create --role "Reader" \
  --assignee "${IDENTITY_CLIENT_ID}" --scope "${RESOURCE_GROUP_ID}"

# Create a federated identity credential
# A binding between the managed identity and the ExternalDNS service account needs to be setup by creating a federated identity resource:
OIDC_ISSUER_URL="$(az aks show -n $AZURE_AKS_CLUSTER_NAME -g $AZURE_AKS_RESOURCE_GROUP --query "oidcIssuerProfile.issuerUrl" -otsv)"
az identity federated-credential create --name ${IDENTITY_NAME} --identity-name ${IDENTITY_NAME} \
--resource-group ${AZURE_AKS_RESOURCE_GROUP} --issuer "$OIDC_ISSUER_URL" --subject "system:serviceaccount:internal-dns:internal-dns"

# use kubectl to create a secret in the cluster that ExternalDNS will use to authenticate with Azure DNS
cat <<-EOF > azure.json
{
  "subscriptionId": "$(az account show --query id -o tsv)",
  "resourceGroup": "$AZURE_DNS_ZONE_RESOURCE_GROUP",
  "useWorkloadIdentityExtension": true,
  "userAssignedIdentityID": "${IDENTITY_CLIENT_ID}"
}
EOF

kubectl create secret generic azure-config-file --namespace "internal-dns" --from-file azure.json --dry-run=client -o yaml | kubectl apply -f -

# To instruct Workload Identity webhook to inject a projected token into the ExternalDNS pod,
# the pod needs to have a label azure.workload.identity/use: "true"
# (before Workload Identity 1.0.0, this label was supposed to be set on the service account instead)

# the service account needs to have an annotation azure.workload.identity/client-id: <IDENTITY_CLIENT_ID>
# it’s also possible to specify (or override) ClientID through userAssignedIdentityID field in azure.json.
