<#
.SYNOPSIS
  Onboard an on-prem Windows Server to Azure Arc for the Sentinel POC.
.NOTES
  Run in an elevated PowerShell session on the target server.
  Requires direct outbound HTTPS (443) to *.his.arc.azure.com, *.guestconfiguration.azure.com,
  login.microsoftonline.com, management.azure.com. See:
  https://learn.microsoft.com/azure/azure-arc/servers/network-requirements
  Populate the variables below from `terraform output` in environments/poc/tf-resources.
#>

$ErrorActionPreference = "Stop"

$TenantId       = "<arc_onboard_tenant_id>"
$SubscriptionId = "<arc_onboard_subscription_id>"
$ResourceGroup  = "<arc_onboard_resource_group>"
$ServicePrincipalId     = "<arc_onboard_client_id>"
$ServicePrincipalSecret = "<arc_onboard_client_secret>"   # from: terraform output -raw arc_onboard_client_secret
$Location       = "westeurope"
$MachineName    = "onprem-win-01"                          # must match arc_windows_machine_name

# 1. Download + install the Connected Machine agent
$agent = "$env:TEMP\AzureConnectedMachineAgent.msi"
Invoke-WebRequest -Uri "https://aka.ms/AzureConnectedMachineAgent" -OutFile $agent -UseBasicParsing
msiexec.exe /i $agent /qn /l*v "$env:TEMP\arc-agent-install.log" | Out-Null

# 2. Connect
& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id $ServicePrincipalId `
  --service-principal-secret $ServicePrincipalSecret `
  --tenant-id $TenantId `
  --subscription-id $SubscriptionId `
  --resource-group $ResourceGroup `
  --location $Location `
  --resource-name $MachineName `
  --tags "workload=microsoft-sentinel,environment=POC"

& "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" show

Write-Host "`nDone. Now set associate_arc_machines = true (and optionally deploy_ama_extensions = true) and re-apply Terraform." -ForegroundColor Green
