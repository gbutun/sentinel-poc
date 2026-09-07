# Copy to sensitive.auto.tfvars (git-ignored). NEVER commit the real file.

# ── Azure target ─────────────────────────────────────────────────────────────
# Subscription : MCAPS-Hybrid-REQ-166508-2026-v-gbutun
# Tenant       : Microsoft Non-Production
subscription_id = "8e9eb8b2-58e2-4d67-a69c-0e75e1e6efd2"
tenant_id       = "16b3c013-d300-468d-ac64-7eda0820b6d3"

# ── Terraform service principal (Contributor + User Access Administrator on the
#    subscription, or Owner) ───────────────────────────────────────────────────
client_id     = "REPLACE_ME"
client_secret = "REPLACE_ME"

# ── Remote state backend (azurerm) ──────────────────────────────────────────
# Storage account created in Sweden Central by bootstrap/create-state-backend.sh
storage_account_name   = "vgbutunpocterraform"
storage_container_name = "tfstate"
storage_access_key     = "REPLACE_ME"
