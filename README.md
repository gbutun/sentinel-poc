# Microsoft Sentinel — POC

Terraform to stand up Microsoft Sentinel and ingest logs from **one on-prem Windows
Server**, **one Linux server**, **one Fortinet firewall** and **one switch**.

- Servers → Azure Arc + Azure Monitor Agent (AMA), direct.
- Fortinet + switch → CEF/syslog to an on-prem **Arc-enabled Linux forwarder** (AMA).

The repo structure and workflow follow the concept used in `terraform-codebase/art-app-azure`:

| Concept | Here |
|---|---|
| Flat `environments/<env>/tf-resources/`, one `.tf` per concern | `environments/poc/tf-resources/` |
| `azurerm` remote backend, config injected at `init` | `deploy.sh init poc` (`-backend-config` flags) |
| SPN auth, secrets out of git | `sensitive.auto.tfvars` (git-ignored; `.example` tracked) |
| Non-secret config | `terraform.tfvars` (`.example` tracked) |
| Naming `{env}-{regionshort}-{resource}-{index}-{unique}` | `poc-weu-la-ws-01-sen`, ... (`locals.tf`) |
| Deploy wrapper with timestamped plans + logs | `deploy.sh` / `deploy.ps1` (`environments/poc/plans`, `.../outputs`) |

> On Windows use `.\deploy.ps1 <action> poc [planTimestamp]` — same arguments as `deploy.sh`.

## Prerequisites

- Terraform >= 1.9, Azure CLI
- An Azure identity with **Contributor + User Access Administrator** (or Owner) on the POC subscription
- On-prem servers with **direct outbound HTTPS (443)** to the Azure Arc endpoints
- Resource providers registered on the subscription: `Microsoft.OperationalInsights`,
  `Microsoft.SecurityInsights`, `Microsoft.Insights`, and — for stage 0 —
  `Microsoft.HybridCompute` (`az provider register -n Microsoft.HybridCompute`)

## Deploy — stage 1 (cloud side)

```bash
# 1. one-time: remote state backend
SUBSCRIPTION_ID=<sub> ./bootstrap/create-state-backend.sh

# 2. config
cd environments/poc/tf-resources
cp terraform.tfvars.example terraform.tfvars
cp sensitive.auto.tfvars.example sensitive.auto.tfvars
# edit both

# 3. deploy
cd ../../..
./deploy.sh init poc
./deploy.sh plan poc
./deploy.sh apply poc <plan-timestamp-from-plan-output>
```

This creates: resource group, Log Analytics workspace, Sentinel onboarding, all
DCRs (Windows, Linux, Fortinet CEF, network syslog), the Azure Activity connector,
and sample analytics rules. No associations or Arc onboarding identity are
created; use an existing approved Arc onboarding identity for the onboarding
scripts. No associations are created yet.

```bash
Use the tenant, subscription, resource group, and approved Arc onboarding
identity values from your existing identity-management process in the
onboarding scripts.
```

## Arc Gateway — stage 0 (optional, before any onboarding)

[Arc Gateway](https://learn.microsoft.com/azure/azure-arc/servers/arc-gateway) is a
managed relay so the on-prem Arc agents reach Azure through **one FQDN**
(`<prefix>.gw.arc.azure.com`) instead of the full Arc endpoint set. Managed
resource — no VM. One gateway per region per subscription.

```hcl
# terraform.tfvars
deploy_arc_gateway = true
```
Needs `Microsoft.HybridCompute` registered on the subscription (see Prerequisites).
`./deploy.sh plan poc && ./deploy.sh apply poc <ts>`, then:

```bash
cd environments/poc/tf-resources
terraform output -raw arc_gateway_id        # -> paste into GATEWAY_ID / $GatewayId in the onboarding scripts
terraform output -raw arc_gateway_endpoint  # the FQDN to allow through the on-prem firewall
```

## Onboard the two servers — stage 2

Fill the outputs into `onboarding/arc-onboard-windows.ps1` /
`onboarding/arc-onboard-linux.sh` (including `GATEWAY_ID` / `$GatewayId` if you
created the gateway in stage 0 — leave it as the `<...>` placeholder to skip),
run each on its server. Then:

```hcl
# terraform.tfvars
associate_arc_machines = true
deploy_ama_extensions  = true
```
`./deploy.sh plan poc && ./deploy.sh apply poc <ts>` → `SecurityEvent` / `Syslog` flow.

## Onboard the network devices — stage 3

Run `onboarding/setup-linux-forwarder.sh` on the on-prem forwarder VM
(Arc-connect + open rsyslog 514 — set `GATEWAY_ID` the same way if using stage 0).
Then:

```hcl
# terraform.tfvars
associate_syslog_forwarder     = true
deploy_forwarder_ama_extension = true
```
`./deploy.sh plan poc && ./deploy.sh apply poc <ts>`. Finally point the Fortinet
and switch at the forwarder per [onboarding/network-device-config.md](onboarding/network-device-config.md),
and enable the **Fortinet FortiGate** Content Hub solution in the portal.

## Beyond the POC

See [docs/architecture.md](docs/architecture.md) — Azure Policy rollout for many
servers, and scaling the forwarder tier (VIP + multiple Arc forwarders) for more
network devices.
