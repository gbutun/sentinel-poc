# ─────────────────────────────────────────────────────────────────────────────
# Identity / connection (values live in sensitive.auto.tfvars - git-ignored)
# ─────────────────────────────────────────────────────────────────────────────
variable "subscription_id" { type = string }
variable "client_id" { type = string }
variable "client_secret" {
  type      = string
  sensitive = true
}
variable "tenant_id" { type = string }

variable "storage_account_name" { type = string }
variable "storage_container_name" { type = string }
variable "storage_access_key" {
  type      = string
  sensitive = true
}

# ─────────────────────────────────────────────────────────────────────────────
# Naming
# ─────────────────────────────────────────────────────────────────────────────
variable "company_name_long" { type = string }
variable "company_name_short" { type = string }
variable "product_name_long" {
  type    = string
  default = "Microsoft Sentinel POC"
}
variable "product_name_short" {
  type    = string
  default = "sentinel"
}
variable "product_unique" {
  type        = string
  description = "Short unique suffix for resource names."
  default     = "sen"
}

variable "environment_short" {
  type    = string
  default = "poc"
}
variable "environment_long" {
  type    = string
  default = "POC"
}

variable "rg_01_location_long" {
  type    = string
  default = "westeurope"
}
variable "rg_01_location_short" {
  type    = string
  default = "weu"
}

# ─────────────────────────────────────────────────────────────────────────────
# Log Analytics workspace
# ─────────────────────────────────────────────────────────────────────────────
variable "la_ws_01_sku" {
  type    = string
  default = "PerGB2018"
}
variable "la_ws_01_retention_in_days" {
  type    = number
  default = 90
}
variable "la_ws_01_daily_quota_gb" {
  type        = number
  description = "Daily ingestion cap in GB. -1 = unlimited. Keep a cap during the POC."
  default     = 5
}

# ─────────────────────────────────────────────────────────────────────────────
# Azure Activity data connector
# ─────────────────────────────────────────────────────────────────────────────
variable "enable_azure_activity_connector" {
  type    = bool
  default = true
}

# ─────────────────────────────────────────────────────────────────────────────
# Arc-enabled servers (on-prem Windows + Linux)
# Set associate_arc_machines / deploy_ama_extensions to true AFTER the two
# machines have been onboarded to Azure Arc (see ../../../onboarding/).
# ─────────────────────────────────────────────────────────────────────────────
variable "arc_machines_resource_group_name" {
  type        = string
  description = "Resource group that will contain the Arc machine objects. Defaults to the POC RG when empty."
  default     = ""
}
variable "arc_windows_machine_name" {
  type    = string
  default = "onprem-win-01"
}
variable "arc_linux_machine_name" {
  type    = string
  default = "onprem-lnx-01"
}
variable "associate_arc_machines" {
  type        = bool
  description = "Create DCR associations for the Arc machines. Requires the machines to already be Arc-connected."
  default     = false
}
variable "deploy_ama_extensions" {
  type        = bool
  description = "Deploy the Azure Monitor Agent extension onto the Arc machines via Terraform."
  default     = false
}

# ─────────────────────────────────────────────────────────────────────────────
# Syslog / Windows event collection tuning
# ─────────────────────────────────────────────────────────────────────────────
variable "syslog_facilities" {
  type    = list(string)
  default = ["auth", "authpriv", "cron", "daemon", "kern", "syslog", "user"]
}
variable "syslog_log_levels" {
  type    = list(string)
  default = ["Warning", "Error", "Critical", "Alert", "Emergency"]
}
variable "windows_event_xpath_queries" {
  type = list(string)
  default = [
    "Security!*[System[(band(Keywords,13510798882111488))]]",
    "System!*[System[(Level=1 or Level=2 or Level=3)]]",
    "Application!*[System[(Level=1 or Level=2 or Level=3)]]",
  ]
}

# ─────────────────────────────────────────────────────────────────────────────
# Sample analytics rules
# ─────────────────────────────────────────────────────────────────────────────
variable "enable_sample_analytics_rules" {
  type    = bool
  default = true
}
