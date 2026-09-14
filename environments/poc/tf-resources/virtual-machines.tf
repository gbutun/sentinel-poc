locals {
  vm = {
    os_disk_storage_account_type = "StandardSSD_LRS"

    ubuntu_image = {
      publisher = "Canonical"
      offer     = "0001-com-ubuntu-server-jammy"
      sku       = "22_04-lts-gen2"
      version   = "latest"
    }
    windows_image = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2022-datacenter-azure-edition"
      version   = "latest"
    }
  }
}

# Simulated on-prem Linux server: gets Arc-connected as var.arc_linux_machine_name
# via onboarding/arc-onboard-linux.sh. No Arc/AMA resources here on purpose -
# onboarding happens by hand, same as it would on a real box.
resource "azurerm_linux_virtual_machine" "rg_01_lnx_srv_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-lnx-srv-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  size                = var.poc_vm_size_linux
  admin_username      = var.poc_vm_admin_username
  admin_password      = var.poc_vm_admin_password
  computer_name       = "onprem-lnx-01"
  network_interface_ids = [
    azurerm_network_interface.rg_01_lnx_srv_01_nic_01[0].id,
  ]

  disable_password_authentication = false

  os_disk {
    name                 = "${local.resource_prefix_rg_01}-lnx-srv-01-os-disk-01-${var.product_unique}"
    caching              = "ReadWrite"
    storage_account_type = local.vm.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = local.vm.ubuntu_image.publisher
    offer     = local.vm.ubuntu_image.offer
    sku       = local.vm.ubuntu_image.sku
    version   = local.vm.ubuntu_image.version
  }

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem Linux server" })
}

# Simulated on-prem syslog/CEF forwarder for the Fortinet firewall + switch.
# Run onboarding/setup-linux-forwarder.sh then onboarding/arc-onboard-linux.sh
# (as var.arc_syslog_forwarder_machine_name) on this box.
resource "azurerm_linux_virtual_machine" "rg_01_lnx_fwd_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-lnx-fwd-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  size                = var.poc_vm_size_linux
  admin_username      = var.poc_vm_admin_username
  admin_password      = var.poc_vm_admin_password
  computer_name       = "onprem-fwd-01"
  network_interface_ids = [
    azurerm_network_interface.rg_01_lnx_fwd_01_nic_01[0].id,
  ]

  disable_password_authentication = false

  os_disk {
    name                 = "${local.resource_prefix_rg_01}-lnx-fwd-01-os-disk-01-${var.product_unique}"
    caching              = "ReadWrite"
    storage_account_type = local.vm.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = local.vm.ubuntu_image.publisher
    offer     = local.vm.ubuntu_image.offer
    sku       = local.vm.ubuntu_image.sku
    version   = local.vm.ubuntu_image.version
  }

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem syslog/CEF forwarder" })
}

# Simulated on-prem Windows server: gets Arc-connected as var.arc_windows_machine_name
# via onboarding/arc-onboard-windows.ps1.
resource "azurerm_windows_virtual_machine" "rg_01_win_srv_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-win-srv-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  size                = var.poc_vm_size_windows
  admin_username      = var.poc_vm_admin_username
  admin_password      = var.poc_vm_admin_password
  computer_name       = "onprem-win-01"
  provision_vm_agent  = true
  network_interface_ids = [
    azurerm_network_interface.rg_01_win_srv_01_nic_01[0].id,
  ]

  os_disk {
    name                 = "${local.resource_prefix_rg_01}-win-srv-01-os-disk-01-${var.product_unique}"
    caching              = "ReadWrite"
    storage_account_type = local.vm.os_disk_storage_account_type
  }

  source_image_reference {
    publisher = local.vm.windows_image.publisher
    offer     = local.vm.windows_image.offer
    sku       = local.vm.windows_image.sku
    version   = local.vm.windows_image.version
  }

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem Windows server" })
}
