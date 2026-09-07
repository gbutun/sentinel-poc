# Azure Arc Gateway - Microsoft.HybridCompute/gateways
#
# A fully managed Azure resource (no OS, no VM): a relay / reverse-proxy
# endpoint that on-prem Arc agents connect out to, so egress can be locked
# down to a single FQDN (<gatewayEndpoint>) instead of the full Arc URL set.
#
# No first-class azurerm resource exists yet, so this uses the azapi provider.
# Enable with `deploy_arc_gateway = true`. Only one gateway per region per
# subscription is supported by the service.

resource "azapi_resource" "arc_gateway_01" {
  count = var.deploy_arc_gateway ? 1 : 0

  # 2025-06-01 is not yet exposed by the HybridCompute RP in all regions;
  # 2025-01-13 (first stable) is broadly available. Schema is identical.
  type = "Microsoft.HybridCompute/gateways@2025-01-13"
  name      = local.arc_gateway_name
  parent_id = azurerm_resource_group.rg_01.id
  location  = azurerm_resource_group.rg_01.location

  body = {
    properties = {
      gatewayType     = "Public"
      allowedFeatures = ["*"]
    }
  }

  response_export_values = [
    "properties.gatewayEndpoint",
    "properties.gatewayId",
    "properties.provisioningState",
  ]

  tags = merge(local.rg_01_resource_tags, { name = "Sentinel POC - Arc Gateway" })
}
