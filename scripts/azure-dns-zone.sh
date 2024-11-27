#! /bin/bash

AZURE_DNS_ZONE_RESOURCE_GROUP="MyDnsResourceGroup" # name of resource group where dns zone is hosted
AZURE_DNS_ZONE="kuberise.internal" # DNS zone name like kuberise.internal or sub.kuberise.internal
AZURE_AKS_RESOURCE_GROUP="kuberise" # name of resource group where aks cluster was created
AZURE_AKS_CLUSTER_NAME="prd-kuberise" # name of aks cluster previously created

# create a Azure resource group named MyDnsResourceGroup that can easily be deleted later
az group create --name "$AZURE_DNS_ZONE_RESOURCE_GROUP" --location "eastus"

# create a Azure DNS zone
az network dns zone create --resource-group "$AZURE_DNS_ZONE_RESOURCE_GROUP" --name "$AZURE_DNS_ZONE"
az account show --query "tenantId"
az account show --query "id"

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
DNS_ID=$(az network dns zone show --name "${AZURE_DNS_ZONE}" \
  --resource-group "${AZURE_DNS_ZONE_RESOURCE_GROUP}" --query "id" --output tsv)
RESOURCE_GROUP_ID=$(az group show --name "${AZURE_DNS_ZONE_RESOURCE_GROUP}" --query "id" --output tsv)

# Grant access to Azure DNS zone for the managed identity:
az role assignment create --role "DNS Zone Contributor" \
  --assignee "${IDENTITY_CLIENT_ID}" --scope "${DNS_ID}"
az role assignment create --role "Reader" \
  --assignee "${IDENTITY_CLIENT_ID}" --scope "${RESOURCE_GROUP_ID}"

# Create a federated identity credential
# A binding between the managed identity and the ExternalDNS service account needs to be setup by creating a federated identity resource:
OIDC_ISSUER_URL="$(az aks show -n $AZURE_AKS_CLUSTER_NAME -g $AZURE_AKS_RESOURCE_GROUP --query "oidcIssuerProfile.issuerUrl" -otsv)"
az identity federated-credential create --name ${IDENTITY_NAME} --identity-name ${IDENTITY_NAME} \
--resource-group ${AZURE_AKS_RESOURCE_GROUP} --issuer "$OIDC_ISSUER_URL" --subject "system:serviceaccount:internal-dns:internal-dns"
