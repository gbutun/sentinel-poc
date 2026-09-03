resource "azurerm_log_analytics_workspace" "rg_01_la_ws_01" {
  name                = "${local.resource_prefix_rg_01}-la-ws-01-${var.product_unique}"
  resource_group_name = azurerm_resource_group.rg_01.name
  location            = azurerm_resource_group.rg_01.location

  sku               = var.la_ws_01_sku
  retention_in_days = var.la_ws_01_retention_in_days
  daily_quota_gb    = var.la_ws_01_daily_quota_gb

  internet_ingestion_enabled = true
  internet_query_enabled     = true

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - Log Analytics workspace" })
}
