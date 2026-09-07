# A couple of scheduled analytics rules so the POC shows end-to-end detections.
# For production, prefer enabling Microsoft's rule templates from Content Hub.

resource "azurerm_sentinel_alert_rule_scheduled" "win_multiple_failed_logons" {
  count                      = var.enable_sample_analytics_rules ? 1 : 0
  name                       = "poc-win-multiple-failed-logons"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.rg_01.workspace_id
  display_name               = "POC - Multiple failed Windows logons from one host"
  severity                   = "Medium"
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 10
  tactics                    = ["CredentialAccess"]

  query = <<-KQL
    SecurityEvent
    | where EventID == 4625
    | summarize FailedAttempts = count() by Computer, Account, bin(TimeGenerated, 15m)
    | where FailedAttempts > 10
  KQL

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "FullName"
      column_name = "Computer"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "fortinet_admin_login_failures" {
  count                      = var.enable_fortinet_sample_rule ? 1 : 0
  name                       = "poc-fortinet-admin-login-failures"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.rg_01.workspace_id
  display_name               = "POC - FortiGate repeated admin login failures"
  severity                   = "Medium"
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 5
  tactics                    = ["CredentialAccess"]

  query = <<-KQL
    CommonSecurityLog
    | where DeviceVendor == "Fortinet"
    | where tolower(Activity) has "login" and tolower(coalesce(Message, AdditionalExtensions, "")) has "fail"
    | summarize Failures = count() by SourceIP, DestinationHostName, bin(TimeGenerated, 15m)
    | where Failures > 5
  KQL

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "SourceIP"
    }
  }
}

resource "azurerm_sentinel_alert_rule_scheduled" "linux_sudo_auth_failures" {
  count                      = var.enable_sample_analytics_rules ? 1 : 0
  name                       = "poc-linux-sudo-auth-failures"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.rg_01.workspace_id
  display_name               = "POC - Repeated sudo / SSH auth failures on Linux"
  severity                   = "Medium"
  query_frequency            = "PT1H"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 10
  tactics                    = ["CredentialAccess"]

  query = <<-KQL
    Syslog
    | where Facility in ("auth", "authpriv")
    | where SyslogMessage has_any ("authentication failure", "Failed password", "sudo:")
    | summarize Failures = count() by Computer, bin(TimeGenerated, 15m)
    | where Failures > 10
  KQL

  entity_mapping {
    entity_type = "Host"
    field_mapping {
      identifier  = "FullName"
      column_name = "Computer"
    }
  }
}
