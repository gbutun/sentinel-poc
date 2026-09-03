#!/usr/bin/env bash
# Onboard an on-prem Linux server to Azure Arc for the Sentinel POC.
# Run as root. Requires direct outbound HTTPS (443) to the Arc endpoints:
#   https://learn.microsoft.com/azure/azure-arc/servers/network-requirements
# Fill the values below from `terraform output` in environments/poc/tf-resources.
set -euo pipefail

TENANT_ID="<arc_onboard_tenant_id>"
SUBSCRIPTION_ID="<arc_onboard_subscription_id>"
RESOURCE_GROUP="<arc_onboard_resource_group>"
SP_ID="<arc_onboard_client_id>"
SP_SECRET="<arc_onboard_client_secret>"     # terraform output -raw arc_onboard_client_secret
LOCATION="westeurope"
MACHINE_NAME="onprem-lnx-01"                # must match arc_linux_machine_name

# 1. Install the Connected Machine agent
wget -q https://aka.ms/azcmagent -O /tmp/install_linux_azcmagent.sh
bash /tmp/install_linux_azcmagent.sh

# 2. Connect
azcmagent connect \
  --service-principal-id "$SP_ID" \
  --service-principal-secret "$SP_SECRET" \
  --tenant-id "$TENANT_ID" \
  --subscription-id "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --resource-name "$MACHINE_NAME" \
  --tags "workload=microsoft-sentinel,environment=POC"

azcmagent show

echo
echo "Done. Now set associate_arc_machines = true (and optionally deploy_ama_extensions = true) and re-apply Terraform."
