# Enables Microsoft Sentinel on the Log Analytics workspace.
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "rg_01" {
  workspace_id                 = azurerm_log_analytics_workspace.rg_01_la_ws_01.id
  customer_managed_key_enabled = false
}
