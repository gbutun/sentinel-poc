# Sentinel POC — architecture & scale-out

## POC scope

```
On-prem                              Azure
┌────────────────┐   Arc agent   ┌──────────────────────────────────────────┐
│ Windows Server │──────────────▶│ Arc-enabled Server  ─┐                    │
│  (AMA ext)     │   443/HTTPS   │                       │  DCR (Windows)     │
└────────────────┘               │                       ▼                    │
                                 │              Log Analytics workspace       │
┌────────────────┐   Arc agent   │                       ▲   + Microsoft      │
│ Linux server   │──────────────▶│ Arc-enabled Server  ─┘     Sentinel        │
│  (AMA ext)     │   443/HTTPS   │  DCR (Syslog)                              │
└────────────────┘               │  Subscription Activity Log ─▶ diag setting │
                                 └──────────────────────────────────────────┘
```

- **Onboarding**: `azcmagent connect` with a least-privilege SPN
  (`Azure Connected Machine Onboarding`) scoped to the POC resource group.
- **Agent**: Azure Monitor Agent, deployed as an Arc machine extension
  (`deploy_ama_extensions`) or by Azure Policy later.
- **Routing**: Data Collection Rules decide what each OS ships.
  - Windows → `Microsoft-SecurityEvent` + `Microsoft-WindowsEvent` (XPath filtered)
  - Linux → `Microsoft-Syslog` (facilities + levels)
- **Sentinel**: `azurerm_sentinel_log_analytics_workspace_onboarding` on the workspace.
- **Content**: for the POC, enable Microsoft's rule templates / workbooks from
  Content Hub in the portal. Two sample scheduled rules are in Terraform to prove
  the pipeline end to end.

## Two-stage apply

| Stage | Flags | Result |
|---|---|---|
| 1 | `associate_arc_machines=false`, `deploy_ama_extensions=false` | Workspace, Sentinel, DCRs, connectors, onboarding SP |
| 2 | both `true` (after `azcmagent connect`) | AMA installed + DCR associations → data flows |

The `data "azurerm_arc_machine"` lookups are `count`-gated so stage 1 never
depends on machines that don't exist yet.

## Scale-out (post-POC)

### Many Windows / Linux servers
- Reuse the **same DCRs** — associations are per-machine, cheap, and scriptable.
- Roll out the Arc agent with the [Arc onboarding script][arc] via GPO (Windows)
  or Ansible/cloud-init/config-mgmt (Linux). Consider a per-site onboarding SP.
- Use **Azure Policy** initiatives:
  - *Enable Azure Monitor Agent on Arc machines*
  - *Associate DCR to Arc machines* (assign the DCR by resource ID)
  This replaces per-machine Terraform associations at fleet scale.
- Split DCRs by role/tier (domain controllers, DMZ, PCI) rather than one big rule;
  keep `x_path_queries` / syslog facilities tight to control ingestion cost.

### Network devices (firewalls, routers, switches)
- No agent on the device. Stand up **1–2 Linux "log forwarder" collector VMs**
  (in Azure or on-prem), Arc-enable them, install AMA.
- Devices send **syslog/CEF** to the collector; AMA reads it via the CEF DCR
  (`enable_cef_collector_dcr = true`, stream `Microsoft-CommonSecurityLog`).
- Size collectors for aggregate EPS; run them behind a load balancer for HA.
- Vendor-specific parsing is handled by Sentinel's CEF/Syslog normalization and
  the relevant Content Hub solution (Palo Alto, Fortinet, Cisco ASA/IOS, etc.).

### Other hardening for production
- Private networking: Azure Monitor Private Link Scope (AMPLS) + Arc private endpoints.
- Move state SPN secret to a pipeline / OIDC; add Checkov + `terraform validate` in CI
  (mirrors the reference repo's pipeline pattern).
- Promote `environments/poc` → `environments/prod` as a sibling folder, same layout.
- Commitment-tier pricing on the workspace once daily volume is known.

[arc]: https://learn.microsoft.com/azure/azure-arc/servers/onboard-service-principal
