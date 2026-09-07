# Network-device collection via the on-prem Arc-enabled Linux forwarder.
#   Fortinet FortiGate  --CEF/514-->  forwarder  --AMA-->  CommonSecurityLog
#   Switch (plain syslog)/514        forwarder  --AMA-->  Syslog
# The forwarder receives on 514 (rsyslog imudp/imtcp), AMA captures locally and
# ships to the workspace per the DCRs below.

resource "azurerm_monitor_data_collection_rule" "dcr_net_cef_01" {
  count               = var.collect_fortinet_cef ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-dcr-net-cef-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  kind                = "Linux"
  description         = "CEF (CommonSecurityLog) from Fortinet firewall via on-prem forwarder -> Sentinel"

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
      facility_names = var.network_syslog_facilities
      log_levels     = var.network_syslog_log_levels
    }
  }

  tags       = local.rg_01_resource_tags
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.rg_01]
}

resource "azurerm_monitor_data_collection_rule" "dcr_net_syslog_01" {
  count               = var.collect_network_syslog ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-dcr-net-syslog-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  kind                = "Linux"
  description         = "Plain syslog from switch / other network gear via on-prem forwarder -> Sentinel"

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
      name           = "network-syslog"
      streams        = [local.streams.syslog]
      facility_names = var.network_syslog_facilities
      log_levels     = var.network_syslog_log_levels
    }
  }

  tags       = local.rg_01_resource_tags
  depends_on = [azurerm_sentinel_log_analytics_workspace_onboarding.rg_01]
}
