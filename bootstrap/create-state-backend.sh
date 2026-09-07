#!/usr/bin/env bash
# One-time: create the Azure Storage account that holds Terraform remote state.
# Run once with an account that can create resources and assign roles in the
# target subscription (az login first). Then put the values into
# sensitive.auto.tfvars.
#
# Auth model: Azure AD / RBAC only. Shared key access is disabled on the
# storage account, so no access key is stored anywhere. The principal that
# runs ./deploy.sh must hold "Storage Blob Data Contributor" on the account.
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-8e9eb8b2-58e2-4d67-a69c-0e75e1e6efd2}"  # MCAPS-Hybrid-REQ-166508-2026-v-gbutun
LOCATION="${LOCATION:-swedencentral}"
RG_NAME="${RG_NAME:-rg-sentinel-poc-tfstate}"
SA_NAME="${SA_NAME:-vgbutunpocterraform}"   # 3-24 lowercase alphanumerics, globally unique
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"

# Object ID of the principal that will run Terraform (service principal or user).
# Leave empty to skip the role assignment and do it manually later.
DEPLOYER_PRINCIPAL_ID="${DEPLOYER_PRINCIPAL_ID:-}"

az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$RG_NAME" --location "$LOCATION" --output none

az storage account create \
  --name "$SA_NAME" --resource-group "$RG_NAME" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false \
  --allow-shared-key-access false --output none

SA_ID="$(az storage account show --name "$SA_NAME" --resource-group "$RG_NAME" --query id -o tsv)"

az storage container create \
  --name "$CONTAINER_NAME" --account-name "$SA_NAME" --auth-mode login --output none

if [[ -n "$DEPLOYER_PRINCIPAL_ID" ]]; then
  az role assignment create \
    --assignee-object-id "$DEPLOYER_PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Storage Blob Data Contributor" \
    --scope "$SA_ID" --output none
  echo "Granted 'Storage Blob Data Contributor' to $DEPLOYER_PRINCIPAL_ID on $SA_NAME"
else
  echo "NOTE: no DEPLOYER_PRINCIPAL_ID given. Grant the Terraform principal"
  echo "      'Storage Blob Data Contributor' on:"
  echo "      $SA_ID"
fi

cat <<EOF

Add these to environments/poc/tf-resources/sensitive.auto.tfvars:

  storage_account_name   = "$SA_NAME"
  storage_container_name  = "$CONTAINER_NAME"

(No storage_access_key - the backend authenticates with Azure AD / RBAC.)
EOF
