# Service principal used by `azcmagent connect` on the on-prem servers.
# Least privilege: "Azure Connected Machine Onboarding" scoped to the POC RG.

resource "azuread_application" "arc_onboard" {
  display_name = "${local.resource_prefix_rg_01}-arc-onboard-${var.product_unique}"
}

resource "azuread_service_principal" "arc_onboard" {
  client_id = azuread_application.arc_onboard.client_id
}

resource "time_rotating" "arc_onboard_secret" {
  rotation_days = 180
}

resource "azuread_service_principal_password" "arc_onboard" {
  service_principal_id = azuread_service_principal.arc_onboard.id
  rotate_when_changed = {
    rotation = time_rotating.arc_onboard_secret.id
  }
}

resource "azurerm_role_assignment" "arc_onboard" {
  scope                = azurerm_resource_group.rg_01.id
  role_definition_name = "Azure Connected Machine Onboarding"
  principal_id         = azuread_service_principal.arc_onboard.object_id
}

# Lets Terraform / operators manage extensions on the onboarded machines.
resource "azurerm_role_assignment" "arc_admin" {
  scope                = azurerm_resource_group.rg_01.id
  role_definition_name = "Azure Connected Machine Resource Administrator"
  principal_id         = azuread_service_principal.arc_onboard.object_id
}
