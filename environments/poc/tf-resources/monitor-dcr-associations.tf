# Bind the DCRs to the Arc machines. Enable via `associate_arc_machines = true`
# once the on-prem Windows + Linux servers are Arc-connected.

resource "azurerm_monitor_data_collection_rule_association" "win_secevent" {
  count                   = var.associate_arc_machines ? 1 : 0
  name                    = "dcra-win-secevent"
  target_resource_id      = data.azurerm_arc_machine.win[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_win_secevent_01.id
  description             = "Windows security events DCR -> ${var.arc_windows_machine_name}"
}

resource "azurerm_monitor_data_collection_rule_association" "lnx_syslog" {
  count                   = var.associate_arc_machines ? 1 : 0
  name                    = "dcra-lnx-syslog"
  target_resource_id      = data.azurerm_arc_machine.lnx[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_lnx_syslog_01.id
  description             = "Linux syslog DCR -> ${var.arc_linux_machine_name}"
}

# ── On-prem forwarder: network-device DCRs ───────────────────────────────────
resource "azurerm_monitor_data_collection_rule_association" "fwd_net_cef" {
  count                   = var.associate_syslog_forwarder && var.collect_fortinet_cef ? 1 : 0
  name                    = "dcra-net-cef"
  target_resource_id      = data.azurerm_arc_machine.fwd[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_net_cef_01[0].id
  description             = "Fortinet CEF DCR -> ${var.arc_syslog_forwarder_machine_name}"
}

resource "azurerm_monitor_data_collection_rule_association" "fwd_net_syslog" {
  count                   = var.associate_syslog_forwarder && var.collect_network_syslog ? 1 : 0
  name                    = "dcra-net-syslog"
  target_resource_id      = data.azurerm_arc_machine.fwd[0].id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr_net_syslog_01[0].id
  description             = "Network syslog DCR -> ${var.arc_syslog_forwarder_machine_name}"
}
