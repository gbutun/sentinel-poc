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
  default = "swedencentral"
}
variable "rg_01_location_short" {
  type    = string
  default = "swc"
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
  description = "Deploy the Azure Monitor Agent extension onto the Arc server machines via Terraform."
  default     = false
}

# ─────────────────────────────────────────────────────────────────────────────
# On-prem syslog / CEF forwarder (Arc-enabled Linux VM in front of the network
# devices: Fortinet firewall + switch). Sources send syslog/CEF to this box on
# 514; AMA on the forwarder ships CommonSecurityLog + Syslog to the workspace.
# Flip the two flags to true AFTER the forwarder VM is Arc-connected AND
# rsyslog is configured to accept remote traffic (onboarding/setup-linux-forwarder.sh).
# ─────────────────────────────────────────────────────────────────────────────
variable "arc_syslog_forwarder_machine_name" {
  type    = string
  default = "onprem-fwd-01"
}
variable "associate_syslog_forwarder" {
  type        = bool
  description = "Create the CEF/Syslog DCR associations for the forwarder. Requires it to be Arc-connected."
  default     = false
}
variable "deploy_forwarder_ama_extension" {
  type        = bool
  description = "Deploy the Azure Monitor Linux Agent extension onto the forwarder via Terraform."
  default     = false
}

# Which network-device streams to collect on the forwarder.
variable "collect_fortinet_cef" {
  type        = bool
  description = "Fortinet FortiGate sends CEF -> CommonSecurityLog table."
  default     = true
}
variable "collect_network_syslog" {
  type        = bool
  description = "Switch (and other plain-syslog gear) -> Syslog table."
  default     = true
}
variable "network_syslog_facilities" {
  type        = list(string)
  description = "Facilities network gear typically logs to."
  default     = ["local0", "local1", "local2", "local3", "local4", "local5", "local6", "local7"]
}
variable "network_syslog_log_levels" {
  type    = list(string)
  default = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
}

# ─────────────────────────────────────────────────────────────────────────────
# Syslog / Windows event collection tuning (direct-attached servers)
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
variable "enable_fortinet_sample_rule" {
  type        = bool
  description = "Adds a sample FortiGate CEF analytics rule (also enable the Fortinet Content Hub solution for the full pack)."
  default     = true
}
