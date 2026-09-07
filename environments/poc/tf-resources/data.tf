data "azurerm_subscription" "current" {}

data "azurerm_client_config" "current" {}

# Arc machine objects created by `azcmagent connect` during onboarding.
# Only read when we are ready to bind DCRs / deploy AMA to them.
data "azurerm_arc_machine" "win" {
  count               = var.associate_arc_machines || var.deploy_ama_extensions ? 1 : 0
  name                = var.arc_windows_machine_name
  resource_group_name = local.arc_machines_resource_group_name
}

data "azurerm_arc_machine" "lnx" {
  count               = var.associate_arc_machines || var.deploy_ama_extensions ? 1 : 0
  name                = var.arc_linux_machine_name
  resource_group_name = local.arc_machines_resource_group_name
}

# On-prem syslog/CEF forwarder (in front of Fortinet firewall + switch).
data "azurerm_arc_machine" "fwd" {
  count               = var.associate_syslog_forwarder || var.deploy_forwarder_ama_extension ? 1 : 0
  name                = var.arc_syslog_forwarder_machine_name
  resource_group_name = local.arc_machines_resource_group_name
}
