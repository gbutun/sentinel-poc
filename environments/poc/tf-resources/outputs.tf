output "resource_group_name" {
  value = azurerm_resource_group.rg_01.name
}

output "location" {
  value = azurerm_resource_group.rg_01.location
}

output "workspace_name" {
  value = azurerm_log_analytics_workspace.rg_01_la_ws_01.name
}

output "workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.rg_01_la_ws_01.id
}

output "workspace_customer_id" {
  description = "Workspace GUID (used by agents)."
  value       = azurerm_log_analytics_workspace.rg_01_la_ws_01.workspace_id
}

output "dcr_windows_id" {
  value = azurerm_monitor_data_collection_rule.dcr_win_secevent_01.id
}

output "dcr_linux_syslog_id" {
  value = azurerm_monitor_data_collection_rule.dcr_lnx_syslog_01.id
}

output "dcr_network_cef_id" {
  value = one(azurerm_monitor_data_collection_rule.dcr_net_cef_01[*].id)
}

output "dcr_network_syslog_id" {
  value = one(azurerm_monitor_data_collection_rule.dcr_net_syslog_01[*].id)
}

output "arc_gateway_id" {
  description = "Arc Gateway resource ID (pass to `azcmagent connect --gateway-id`)."
  value       = one(azapi_resource.arc_gateway_01[*].id)
}

output "arc_gateway_endpoint" {
  description = "Arc Gateway endpoint FQDN (<prefix>.gw.arc.azure.com)."
  value       = try(azapi_resource.arc_gateway_01[0].output.properties.gatewayEndpoint, null)
}

output "syslog_forwarder_machine_name" {
  description = "Arc machine name the forwarder must be onboarded as."
  value       = var.arc_syslog_forwarder_machine_name
}

output "poc_vm_public_ips" {
  description = "Public IPs of the simulated on-prem VMs (SSH/RDP, locked to trusted_source_cidrs)."
  value = var.deploy_poc_vms ? {
    lnx_srv = azurerm_public_ip.rg_01_lnx_srv_01_pip_01[0].ip_address
    lnx_fwd = azurerm_public_ip.rg_01_lnx_fwd_01_pip_01[0].ip_address
    win_srv = azurerm_public_ip.rg_01_win_srv_01_pip_01[0].ip_address
  } : null
}

output "poc_vm_private_ips" {
  description = "Private IPs of the simulated on-prem VMs, within the on-prem VNet."
  value       = var.deploy_poc_vms ? local.poc_vm_ips : null
}

