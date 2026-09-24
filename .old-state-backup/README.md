# Old Terraform state backups

Local state files for tenants that are **not** the active target of
`environments/poc/tf-resources`. The `.tfstate` files are git-ignored; only this
README is tracked.

The active state is always `environments/poc/tf-resources/terraform.tfstate`,
and it must match `subscription_id` / `tenant_id` in `sensitive.auto.tfvars`.
If it doesn't, `./deploy.sh plan poc` fails with `InvalidAuthenticationTokenTenant`.

## Files

| File | Tenant | Subscription | Saved | Serial | Status |
|---|---|---|---|---|---|
| `terraform.tfstate.old-sub-4366f64f` | AnkaCore (`0fd019a7…`) | `4366f64f…` | 2026-09-08 15:06 | 25 | **Stale.** Restored as the active state on 2026-09-24 and applied since then, so the active copy is newer |
| `terraform.tfstate.backup.old-sub-4366f64f` | AnkaCore (`0fd019a7…`) | `4366f64f…` | 2026-09-08 14:41 | 21 | Previous version of the above |
| `terraform.tfstate.old-sub-5a6a4915` | Eren Holding (`bcb5eab3…`) | `5a6a4915…` | 2026-09-21 11:45 | 18 | **Latest Eren Holding state.** Keep it: it is the only record of that deployment |
| `terraform.tfstate.backup.old-sub-5a6a4915` | Eren Holding (`bcb5eab3…`) | `5a6a4915…` | 2026-09-21 11:38 | 13 | Previous version of the above |

A higher serial means a newer file. `.backup` is the version just before its
matching file.

## Switching tenants

1. Move the active state out, naming it after its subscription:
   ```bash
   cd environments/poc/tf-resources
   mv terraform.tfstate        ../../../.old-state-backup/terraform.tfstate.old-sub-<sub8>
   mv terraform.tfstate.backup ../../../.old-state-backup/terraform.tfstate.backup.old-sub-<sub8>
   ```
2. Copy the target tenant's latest file (not the `.backup`) in as `terraform.tfstate`.
3. Point `sensitive.auto.tfvars` at the same subscription and tenant, and run `az login --tenant <tenant>`.
4. Run `./deploy.sh plan poc`. If it shows no unexpected changes, the state and target match.
5. Update the table above.
