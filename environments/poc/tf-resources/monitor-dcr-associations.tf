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
