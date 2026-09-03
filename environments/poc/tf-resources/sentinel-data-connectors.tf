# Azure Activity connector (current method): stream the subscription Activity Log
# into the Sentinel workspace via a diagnostic setting.
resource "azurerm_monitor_diagnostic_setting" "azure_activity" {
  count                      = var.enable_azure_activity_connector ? 1 : 0
  name                       = "sentinel-azure-activity"
  target_resource_id         = data.azurerm_subscription.current.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.rg_01_la_ws_01.id

  enabled_log { category = "Administrative" }
  enabled_log { category = "Security" }
  enabled_log { category = "ServiceHealth" }
  enabled_log { category = "Alert" }
  enabled_log { category = "Recommendation" }
  enabled_log { category = "Policy" }
  enabled_log { category = "Autoscale" }
  enabled_log { category = "ResourceHealth" }

  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.rg_01]
}

# NOTE: the Windows Security Events and Syslog connectors are implemented as the
# DCRs in monitor-dcr-windows.tf / monitor-dcr-linux-syslog.tf. Content Hub
# solutions (rule templates, workbooks, hunting queries) are installed from the
# portal for the POC; see docs/architecture.md for the azapi option at scale.
