# Sentinel POC — architecture & scale-out

## POC scope

Sources: **1 Windows Server**, **1 Linux server**, **1 Fortinet firewall**, **1 switch**.

```
On-prem                                             Azure
┌────────────────┐   Arc + AMA                ┌─────────────────────────────────┐
│ Windows Server │───────────────────────────▶│ Arc srv ─ DCR (SecurityEvent)  ─┐│
└────────────────┘   443/HTTPS                │                                 ││
┌────────────────┐   Arc + AMA                │ Arc srv ─ DCR (Syslog)         ─┤│
│ Linux server   │───────────────────────────▶│                                 ││
└────────────────┘                            │                                 ▼│
┌────────────────┐  CEF/514  ┌─────────────┐  │           Log Analytics WS       │
│ Fortinet FW    │──────────▶│ on-prem     │  │           + Microsoft Sentinel   │
├────────────────┤  syslog   │ Linux       │──▶ Arc fwd ─ DCR (CommonSecurityLog)│
│ Switch         │──514─────▶│ FORWARDER   │  │           DCR (Syslog)          ▲ │
└────────────────┘           │ Arc + AMA   │  │  Subscription Activity ─ diag ──┘ │
                             └─────────────┘  └─────────────────────────────────┘
```

- **Servers**: direct Arc + AMA. DCRs decide what each ships.
  - Windows → `Microsoft-SecurityEvent` + `Microsoft-WindowsEvent` (XPath filtered)
  - Linux → `Microsoft-Syslog` (facilities + levels)
- **Network devices**: no agent. Fortinet sends **CEF** and the switch sends
  **plain syslog** to the on-prem **forwarder** (Arc + AMA) on 514. AMA on the
  forwarder ships `Microsoft-CommonSecurityLog` (Fortinet) and `Microsoft-Syslog`
  (switch). Device config: `onboarding/network-device-config.md`.
- **Onboarding**: `azcmagent connect` with a least-privilege SPN
  (`Azure Connected Machine Onboarding`) scoped to the POC resource group — same
  SPN for the two servers and the forwarder.
- **Sentinel**: `azurerm_sentinel_log_analytics_workspace_onboarding` on the workspace.
- **Content**: enable Microsoft's rule templates / workbooks / parsers from Content
  Hub in the portal — in particular the **Fortinet FortiGate** solution. Sample
  scheduled rules (Windows, Linux, FortiGate) are in Terraform to prove the pipeline.

## Staged apply

| Stage | Flags | Result |
|---|---|---|
| 1 | all `associate_*` / `deploy_*` false | Workspace, Sentinel, all DCRs, Azure Activity connector, Arc onboarding SP |
| 2 | `associate_arc_machines=true`, `deploy_ama_extensions=true` (after `azcmagent connect` on both servers) | Server AMA + DCR associations → SecurityEvent / Syslog flow |
| 3 | `associate_syslog_forwarder=true`, `deploy_forwarder_ama_extension=true` (after `setup-linux-forwarder.sh` on the forwarder) | Forwarder AMA + CEF/Syslog associations; then point devices at it |

All `data "azurerm_arc_machine"` lookups are `count`-gated, so earlier stages
never depend on machines that don't exist yet. DCRs are created in stage 1
(harmless without associations).

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
- Same forwarder pattern the POC already uses (`onprem-fwd-01`), just scaled:
  add more Arc-enabled Linux forwarders and put them behind a VIP / load balancer,
  sized for aggregate EPS.
- Devices keep sending **syslog/CEF** to the forwarder VIP on 514; the CEF
  (`Microsoft-CommonSecurityLog`) and Syslog DCRs are unchanged — just associate
  them to each new forwarder.
- Vendor parsing comes from Sentinel's CEF/Syslog normalization + the relevant
  Content Hub solution (Fortinet, Palo Alto, Cisco ASA/IOS, Arista, etc.).

### Other hardening for production
- Private networking: Azure Monitor Private Link Scope (AMPLS) + Arc private endpoints.
- Move state SPN secret to a pipeline / OIDC; add Checkov + `terraform validate` in CI
  (mirrors the reference repo's pipeline pattern).
- Promote `environments/poc` → `environments/prod` as a sibling folder, same layout.
- Commitment-tier pricing on the workspace once daily volume is known.

[arc]: https://learn.microsoft.com/azure/azure-arc/servers/onboard-service-principal
