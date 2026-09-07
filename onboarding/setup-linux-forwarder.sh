#!/usr/bin/env bash
# Prepare the on-prem Linux syslog/CEF forwarder for the Sentinel POC.
#   1. Arc-connect the VM   2. open rsyslog to remote 514   3. hand off to AMA
# Run as root on the forwarder VM. Fill values from `terraform output` in
# environments/poc/tf-resources. Requires outbound 443 to the Arc endpoints
# (or, with GATEWAY_ID set, to the Arc Gateway FQDN <prefix>.gw.arc.azure.com).
set -euo pipefail

TENANT_ID="<arc_onboard_tenant_id>"
SUBSCRIPTION_ID="<arc_onboard_subscription_id>"
RESOURCE_GROUP="<arc_onboard_resource_group>"
SP_ID="<arc_onboard_client_id>"
SP_SECRET="<arc_onboard_client_secret>"        # terraform output -raw arc_onboard_client_secret
LOCATION="westeurope"
MACHINE_NAME="onprem-fwd-01"                   # must match arc_syslog_forwarder_machine_name
GATEWAY_ID="<arc_gateway_id>"                  # terraform output -raw arc_gateway_id (leave as placeholder to skip)

# ── 1. Azure Connected Machine agent ────────────────────────────────────────
wget -q https://aka.ms/azcmagent -O /tmp/install_linux_azcmagent.sh
bash /tmp/install_linux_azcmagent.sh

CONNECT_EXTRA=()
[[ "$GATEWAY_ID" == \<*\> ]] || CONNECT_EXTRA+=(--gateway-id "$GATEWAY_ID")

azcmagent connect \
  --service-principal-id "$SP_ID" \
  --service-principal-secret "$SP_SECRET" \
  --tenant-id "$TENANT_ID" \
  --subscription-id "$SUBSCRIPTION_ID" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --resource-name "$MACHINE_NAME" \
  --tags "workload=microsoft-sentinel,environment=POC,role=syslog-forwarder" \
  "${CONNECT_EXTRA[@]}"

# ── 2. Accept remote syslog on 514 (UDP + TCP) ─────────────────────────────
# AMA drops its own /etc/rsyslog.d/*-azuremonitoragent.conf that forwards to the
# AMA socket; we only need rsyslog to *receive* from the network devices.
cat >/etc/rsyslog.d/10-remote-in.conf <<'EOF'
module(load="imudp")
input(type="imudp" port="514")
module(load="imtcp")
input(type="imtcp" port="514")
EOF

if command -v systemctl >/dev/null; then
  systemctl restart rsyslog
else
  service rsyslog restart
fi

# open the host firewall if firewalld/ufw is active
command -v firewall-cmd >/dev/null && { firewall-cmd --permanent --add-port=514/udp; firewall-cmd --permanent --add-port=514/tcp; firewall-cmd --reload; } || true
command -v ufw >/dev/null && { ufw allow 514/udp; ufw allow 514/tcp; } || true

azcmagent show
echo
echo "Forwarder Arc-connected and listening on 514."
echo "Next: set deploy_forwarder_ama_extension = true and associate_syslog_forwarder = true, then re-apply Terraform."
echo "Then point the devices at this host (see onboarding/network-device-config.md)."
