#!/usr/bin/env bash
# One-time: create the Azure Storage account that holds Terraform remote state.
# Run once with an account that can create resources in the target subscription
# (az login first). Then put the values into sensitive.auto.tfvars.
set -euo pipefail

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:?set SUBSCRIPTION_ID}"
LOCATION="${LOCATION:-westeurope}"
RG_NAME="${RG_NAME:-rg-sentinel-poc-tfstate}"
SA_NAME="${SA_NAME:-stsentinelpoctfstate}"   # 3-24 lowercase alphanumerics, globally unique
CONTAINER_NAME="${CONTAINER_NAME:-tfstate}"

az account set --subscription "$SUBSCRIPTION_ID"
az group create --name "$RG_NAME" --location "$LOCATION" --output none

az storage account create \
  --name "$SA_NAME" --resource-group "$RG_NAME" --location "$LOCATION" \
  --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false --output none

KEY="$(az storage account keys list --account-name "$SA_NAME" --resource-group "$RG_NAME" --query '[0].value' -o tsv)"

az storage container create \
  --name "$CONTAINER_NAME" --account-name "$SA_NAME" --account-key "$KEY" --output none

cat <<EOF

Add these to environments/poc/tf-resources/sensitive.auto.tfvars:

  storage_account_name   = "$SA_NAME"
  storage_container_name  = "$CONTAINER_NAME"
  storage_access_key      = "$KEY"
EOF
