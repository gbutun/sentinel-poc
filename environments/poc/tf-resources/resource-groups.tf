resource "azurerm_resource_group" "rg_01" {
  name     = "${local.resource_prefix_rg_01}-rg-01-${var.product_unique}"
  location = var.rg_01_location_long

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - primary resource group" })
}
