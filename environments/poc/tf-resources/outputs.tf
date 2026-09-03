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

# ── Azure Arc onboarding inputs for onboarding/arc-onboard-*.{ps1,sh} ──────────
output "arc_onboard_tenant_id" {
  value = var.tenant_id
}

output "arc_onboard_subscription_id" {
  value = var.subscription_id
}

output "arc_onboard_resource_group" {
  value = local.arc_machines_resource_group_name
}

output "arc_onboard_client_id" {
  value = azuread_application.arc_onboard.client_id
}

output "arc_onboard_client_secret" {
  sensitive = true
  value     = azuread_service_principal_password.arc_onboard.value
}
