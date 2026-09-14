# Stage -1: "on-prem" simulation network.
#
# The POC architecture (docs/architecture.md) assumes a Windows server, a
# Linux server and a Linux syslog forwarder already exist somewhere and just
# get Arc-connected (onboarding/arc-onboard-*.sh). Since there's no real
# on-prem site for this lab, these three Azure VMs stand in for them - plain
# VMs with no Arc/AMA extension attached by Terraform, onboarded by hand via
# `azcmagent connect` exactly like a real on-prem box would be.
#
# Gated behind deploy_poc_vms so the rest of the stack (workspace, Sentinel,
# DCRs, Arc onboarding SP) can be applied without ever needing these.

resource "azurerm_virtual_network" "rg_01_onprem_vn_01" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-onprem-vn-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location
  address_space       = [var.onprem_vnet_address_space]

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - simulated on-prem VNet" })
}

resource "azurerm_subnet" "rg_01_onprem_vn_01_srv_sub_01" {
  count                = var.deploy_poc_vms ? 1 : 0
  name                 = "${local.resource_prefix_rg_01}-onprem-srv-sub-01-${var.product_unique}"
  resource_group_name  = azurerm_resource_group.rg_01.name
  virtual_network_name = azurerm_virtual_network.rg_01_onprem_vn_01[0].name
  address_prefixes     = [var.onprem_subnet_address_space]
}

resource "azurerm_network_security_group" "rg_01_onprem_srv_sub_01_nsg" {
  count               = var.deploy_poc_vms ? 1 : 0
  name                = "${local.resource_prefix_rg_01}-onprem-srv-sub-01-nsg-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - on-prem subnet NSG" })
}

# Management access (SSH/RDP) - only opened when a trusted source is set.
resource "azurerm_network_security_rule" "allow_ssh" {
  count                       = var.deploy_poc_vms && length(var.trusted_source_cidrs) > 0 ? 1 : 0
  name                        = "allow-ssh-from-trusted"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.trusted_source_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_01.name
  network_security_group_name = azurerm_network_security_group.rg_01_onprem_srv_sub_01_nsg[0].name
}

resource "azurerm_network_security_rule" "allow_rdp" {
  count                       = var.deploy_poc_vms && length(var.trusted_source_cidrs) > 0 ? 1 : 0
  name                        = "allow-rdp-from-trusted"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefixes     = var.trusted_source_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_01.name
  network_security_group_name = azurerm_network_security_group.rg_01_onprem_srv_sub_01_nsg[0].name
}

# Syslog/CEF (514) into the forwarder - from inside the VNet only, since the
# "network devices" (Fortinet, switch) are simulated on the same subnet.
resource "azurerm_network_security_rule" "allow_syslog_from_vnet" {
  count                       = var.deploy_poc_vms ? 1 : 0
  name                        = "allow-syslog-cef-from-vnet"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "514"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_01.name
  network_security_group_name = azurerm_network_security_group.rg_01_onprem_srv_sub_01_nsg[0].name
}

resource "azurerm_subnet_network_security_group_association" "rg_01_onprem_srv_sub_01_nsg_assoc" {
  count                     = var.deploy_poc_vms ? 1 : 0
  subnet_id                 = azurerm_subnet.rg_01_onprem_vn_01_srv_sub_01[0].id
  network_security_group_id = azurerm_network_security_group.rg_01_onprem_srv_sub_01_nsg[0].id
}
