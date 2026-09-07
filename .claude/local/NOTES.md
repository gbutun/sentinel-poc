# Local working notes — sentinel-poc

Not shared. `.claude/local/` is git-ignored.

## Project

Microsoft Sentinel rollout. **Stage 1 = POC** sources: 1 on-prem Windows Server,
1 Linux server, 1 Fortinet firewall, 1 switch. Later: many servers + many network
devices.

Deploy path:
- Servers → **Azure Arc** (`azcmagent connect`, outbound 443) → **AMA** → DCRs → workspace.
- Fortinet + switch → CEF/plain syslog on 514 → **on-prem Arc-enabled Linux forwarder**
  (`onprem-fwd-01`, Arc + AMA) → DCRs (`CommonSecurityLog` for Fortinet, `Syslog` for switch).
- Workspace has **Microsoft Sentinel** enabled; Fortinet Content Hub solution enabled in portal.

Staged apply via tfvars flags: stage 1 = cloud + DCRs + onboarding SP (all flags false);
stage 2 = `associate_arc_machines`/`deploy_ama_extensions` after server onboarding;
stage 3 = `associate_syslog_forwarder`/`deploy_forwarder_ama_extension` after
`onboarding/setup-linux-forwarder.sh`.

Repo follows the "concept" of `/home/ronin/projects/terraform-codebase/art-app-azure`
(git-ignored, local-only reference): flat `environments/<env>/tf-resources/` with one
`.tf` per concern, `azurerm` backend configured at `init` via `-backend-config` flags
from `deploy.sh`, SPN auth in git-ignored `sensitive.auto.tfvars`, non-secret
`terraform.tfvars`, naming `{env}-{regionshort}-{resource}-{index}-{unique}`.

Two-stage apply: `associate_arc_machines` / `deploy_ama_extensions` default false
(stage 1 = cloud side + Arc onboarding SP), flip to true after `azcmagent connect`
(stage 2 = AMA + DCR associations). Network-device CEF path is `enable_cef_collector_dcr`
(post-POC).

## Target Azure environment

- Subscription: `MCAPS-Hybrid-REQ-166508-2026-v-gbutun` / `8e9eb8b2-58e2-4d67-a69c-0e75e1e6efd2`
- Tenant: `Microsoft Non-Production` / `16b3c013-d300-468d-ac64-7eda0820b6d3`
- Region: Sweden Central (`swedencentral`, short `swc`)
- TF state: storage account `vgbutunpocterraform`, container `tfstate`

## Working agreement

- `terraform-codebase/art-app-azure` is **read-only reference** — never edit it.
- No `terraform init/plan/apply` against Azure, no deployments, unless explicitly asked.
  Provider-only `terraform init -backend=false` + `validate` (no Azure auth) is fine.
- Scaffolding = new local files under `sentinel-poc/` only.
