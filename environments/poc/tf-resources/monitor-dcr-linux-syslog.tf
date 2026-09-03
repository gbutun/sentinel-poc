# "Syslog via AMA" Sentinel connector == a DCR that collects syslog from the
# Linux Arc machine(s). AMA reconfigures rsyslog/syslog-ng on association.
resource "azurerm_monitor_data_collection_rule" "dcr_lnx_syslog_01" {
  name                = "${local.resource_prefix_rg_01}-dcr-lnx-syslog-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  kind                = "Linux"
  description         = "Linux syslog -> Sentinel"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.rg_01_la_ws_01.id
      name                  = "sentinel-workspace"
    }
  }

  data_flow {
    streams      = [local.streams.syslog]
    destinations = ["sentinel-workspace"]
  }

  data_sources {
    syslog {
      name           = "linux-syslog"
      streams        = [local.streams.syslog]
      facility_names = var.syslog_facilities
      log_levels     = var.syslog_log_levels
    }
  }

  tags       = local.rg_01_resource_tags
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.rg_01]
}
