locals {
  # {env}-{regionshort}-{resource}-{index}-{unique}   e.g. poc-weu-la-ws-01-sen
  resource_prefix_rg_01 = "${var.environment_short}-${var.rg_01_location_short}"

  product_name_long = format("%s (%s)", var.product_name_long, var.environment_long)

  arc_machines_resource_group_name = coalesce(
    var.arc_machines_resource_group_name,
    azurerm_resource_group.rg_01.name,
  )

  resource_tags = {
    company     = var.company_name_long
    product     = local.product_name_long
    environment = var.environment_long
    managed_by  = "terraform"
    workload    = "microsoft-sentinel"
  }

  rg_01_resource_tags = merge(local.resource_tags, { region = var.rg_01_location_long })

  # DCR stream identifiers
  streams = {
    security_event = "Microsoft-SecurityEvent"
    windows_event  = "Microsoft-WindowsEvent"
    syslog         = "Microsoft-Syslog"
    common_sec_log = "Microsoft-CommonSecurityLog" # CEF (network devices)
  }
}
