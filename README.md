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
- A Terraform service principal: **Contributor + User Access Administrator** (or Owner) on the POC subscription
- On-prem servers with **direct outbound HTTPS (443)** to the Azure Arc endpoints

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
sample analytics rules, and the **Arc onboarding service principal**. No
associations yet.

```bash
cd environments/poc/tf-resources
terraform output arc_onboard_client_id
terraform output -raw arc_onboard_client_secret
```

## Onboard the two servers — stage 2

Fill the outputs into `onboarding/arc-onboard-windows.ps1` /
`onboarding/arc-onboard-linux.sh`, run each on its server. Then:

```hcl
# terraform.tfvars
associate_arc_machines = true
deploy_ama_extensions  = true
```
`./deploy.sh plan poc && ./deploy.sh apply poc <ts>` → `SecurityEvent` / `Syslog` flow.

## Onboard the network devices — stage 3

Run `onboarding/setup-linux-forwarder.sh` on the on-prem forwarder VM
(Arc-connect + open rsyslog 514). Then:

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
