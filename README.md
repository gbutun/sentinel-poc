# Microsoft Sentinel — POC

Terraform to stand up Microsoft Sentinel and ingest logs from **one on-prem Windows
Server** and **one on-prem Linux machine** via Azure Arc + Azure Monitor Agent (AMA).

The repo structure and workflow follow the concept used in `terraform-codebase/art-app-azure`:

| Concept | Here |
|---|---|
| Flat `environments/<env>/tf-resources/`, one `.tf` per concern | `environments/poc/tf-resources/` |
| `azurerm` remote backend, config injected at `init` | `deploy.sh init poc` (`-backend-config` flags) |
| SPN auth, secrets out of git | `sensitive.auto.tfvars` (git-ignored; `.example` tracked) |
| Non-secret config | `terraform.tfvars` (`.example` tracked) |
| Naming `{env}-{regionshort}-{resource}-{index}-{unique}` | `poc-weu-la-ws-01-sen`, ... (`locals.tf`) |
| Deploy wrapper with timestamped plans + logs | `deploy.sh` (`environments/poc/plans`, `.../outputs`) |

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

This creates: resource group, Log Analytics workspace, Sentinel onboarding,
Windows + Linux DCRs, the Azure Activity connector, sample analytics rules, and
the **Arc onboarding service principal**.

## Onboard the on-prem servers — stage 2

```bash
cd environments/poc/tf-resources
terraform output arc_onboard_client_id
terraform output -raw arc_onboard_client_secret
```

Fill the values into `onboarding/arc-onboard-windows.ps1` / `onboarding/arc-onboard-linux.sh`,
run each on its server. Then:

```hcl
# terraform.tfvars
associate_arc_machines = true
deploy_ama_extensions  = true
```

```bash
./deploy.sh plan poc && ./deploy.sh apply poc <ts>
```

Now AMA is installed and the DCRs are bound — `SecurityEvent` and `Syslog`
tables start filling in the workspace.

## Beyond the POC

See [docs/architecture.md](docs/architecture.md) — scaling to many servers (Azure
Policy rollout) and onboarding **network devices** (firewalls/routers/switches)
via CEF to Linux forwarder collectors (`enable_cef_collector_dcr`).
