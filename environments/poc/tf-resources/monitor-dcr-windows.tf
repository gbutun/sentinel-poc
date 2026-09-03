# "Windows Security Events via AMA" Sentinel connector == a DCR that ships the
# Security event log (and selected System/Application events) to the workspace.
resource "azurerm_monitor_data_collection_rule" "dcr_win_secevent_01" {
  name                = "${local.resource_prefix_rg_01}-dcr-win-secevent-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  kind                = "Windows"
  description         = "Windows security / system / application events -> Sentinel"

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.rg_01_la_ws_01.id
      name                  = "sentinel-workspace"
    }
  }

  data_flow {
    streams      = [local.streams.security_event, local.streams.windows_event]
    destinations = ["sentinel-workspace"]
  }

  data_sources {
    windows_event_log {
      name           = "win-event-logs"
      streams        = [local.streams.security_event, local.streams.windows_event]
      x_path_queries = var.windows_event_xpath_queries
    }
  }

  tags       = local.rg_01_resource_tags
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.rg_01]
}
