# POST-POC: CEF / CommonSecurityLog collection for network devices (firewalls,
# routers, switches). Devices send syslog/CEF to one or more Linux log-forwarder
# collector VMs; those collectors run AMA and are associated with this DCR.
# Kept disabled during the POC.
variable "enable_cef_collector_dcr" {
  type    = bool
  default = false
}

resource "azurerm_monitor_data_collection_rule" "dcr_cef_01" {
  count               = var.enable_cef_collector_dcr ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-dcr-cef-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  kind                = "Linux"
  description         = "CEF (CommonSecurityLog) from network devices via Linux forwarder -> Sentinel"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.rg_01_la_ws_01.id
      name                  = "sentinel-workspace"
    }
  }

  data_flow {
    streams      = [local.streams.common_sec_log]
    destinations = ["sentinel-workspace"]
  }

  data_sources {
    syslog {
      name           = "cef-collector"
      streams        = [local.streams.common_sec_log]
      facility_names = ["local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }

  tags       = local.rg_01_resource_tags
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.rg_01]
}
