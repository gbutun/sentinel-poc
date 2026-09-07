# Optionally deploy the Azure Monitor Agent onto the Arc machines from Terraform.
# Alternative: let Azure Policy ("Configure ... to run Azure Monitor Agent") do it.
# Enable via `deploy_ama_extensions = true`.

resource "azurerm_arc_machine_extension" "win_ama" {
  count                     = var.deploy_ama_extensions ? 1 : 0
  name                      = "AzureMonitorWindowsAgent"
  arc_machine_id            = data.azurerm_arc_machine.win[0].id
  location                  = data.azurerm_arc_machine.win[0].location
  publisher                 = "Microsoft.Azure.Monitor"
  type                      = "AzureMonitorWindowsAgent"
  type_handler_version      = "1.0"
  automatic_upgrade_enabled = true

  tags = local.rg_01_resource_tags
}

resource "azurerm_arc_machine_extension" "lnx_ama" {
  count                     = var.deploy_ama_extensions ? 1 : 0
  name                      = "AzureMonitorLinuxAgent"
  arc_machine_id            = data.azurerm_arc_machine.lnx[0].id
  location                  = data.azurerm_arc_machine.lnx[0].location
  publisher                 = "Microsoft.Azure.Monitor"
  type                      = "AzureMonitorLinuxAgent"
  type_handler_version      = "1.0"
  automatic_upgrade_enabled = true

  tags = local.rg_01_resource_tags
}

# On-prem syslog/CEF forwarder (Linux).
resource "azurerm_arc_machine_extension" "fwd_ama" {
  count                     = var.deploy_forwarder_ama_extension ? 1 : 0
  name                      = "AzureMonitorLinuxAgent"
  arc_machine_id            = data.azurerm_arc_machine.fwd[0].id
  location                  = data.azurerm_arc_machine.fwd[0].location
  publisher                 = "Microsoft.Azure.Monitor"
  type                      = "AzureMonitorLinuxAgent"
  type_handler_version      = "1.0"
  automatic_upgrade_enabled = true

  tags = local.rg_01_resource_tags
}
