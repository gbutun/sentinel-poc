locals {
  poc_vm_ips = var.deploy_poc_vms ? {
    lnx_srv = cidrhost(var.onprem_subnet_address_space, 4)
    lnx_fwd = cidrhost(var.onprem_subnet_address_space, 5)
    win_srv = cidrhost(var.onprem_subnet_address_space, 6)
  } : {}
}

# Public IPs are only needed for hands-on management (SSH/RDP) during the POC.
# NSG rules above keep them locked to var.trusted_source_cidrs.
resource "azurerm_public_ip" "rg_01_lnx_srv_01_pip_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-lnx-srv-01-pip-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem Linux server public IP" })
}

resource "azurerm_public_ip" "rg_01_lnx_fwd_01_pip_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-lnx-fwd-01-pip-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem syslog forwarder public IP" })
}

resource "azurerm_public_ip" "rg_01_win_srv_01_pip_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-win-srv-01-pip-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem Windows server public IP" })
}

resource "azurerm_network_interface" "rg_01_lnx_srv_01_nic_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-lnx-srv-01-nic-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location

  ip_configuration {
    name                          = "lnx-srv-01-ip-config-01"
    subnet_id                     = azurerm_subnet.rg_01_onprem_vn_01_srv_sub_01[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.poc_vm_ips.lnx_srv
    public_ip_address_id          = azurerm_public_ip.rg_01_lnx_srv_01_pip_01[0].id
  }

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem Linux server NIC" })
}

resource "azurerm_network_interface" "rg_01_lnx_fwd_01_nic_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-lnx-fwd-01-nic-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location

  ip_configuration {
    name                          = "lnx-fwd-01-ip-config-01"
    subnet_id                     = azurerm_subnet.rg_01_onprem_vn_01_srv_sub_01[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.poc_vm_ips.lnx_fwd
    public_ip_address_id          = azurerm_public_ip.rg_01_lnx_fwd_01_pip_01[0].id
  }

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem syslog forwarder NIC" })
}

resource "azurerm_network_interface" "rg_01_win_srv_01_nic_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-win-srv-01-nic-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location

  ip_configuration {
    name                          = "win-srv-01-ip-config-01"
    subnet_id                     = azurerm_subnet.rg_01_onprem_vn_01_srv_sub_01[0].id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.poc_vm_ips.win_srv
    public_ip_address_id          = azurerm_public_ip.rg_01_win_srv_01_pip_01[0].id
  }

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem Windows server NIC" })
}
