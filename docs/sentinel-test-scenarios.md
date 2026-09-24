# Sentinel test scenarios (Linux agents)

Real actions to run on the Linux agents (tekaden, zura) that produce Sentinel alerts
and incidents. Nothing here is simulated: each command causes genuine
authentication activity that the system logs itself.

```
action on tekaden/zura -> local rsyslog -> TCP 514 -> voltron (onprem-fwd-01)
  -> AMA (DCR facility/level filter) -> Syslog table -> analytics rule -> Alert -> Incident
```

## Prerequisites

1. **Info-level Linux logs are collected.** Real sshd/sudo/passwd events log at
   `auth.info` / `authpriv.notice`, below the old Warning+ filter.
   `syslog_log_levels` in `environments/poc/tf-resources/terraform.tfvars` must include
   `"Info"` and `"Notice"`. Deploy it with `./deploy.sh plan poc`, then `./deploy.sh apply poc <timestamp>`.
2. **These Microsoft rule templates are enabled** (Syslog solution, already installed).
   In Sentinel, go to **Analytics → Rule templates**, search for each name, and click **Create rule**.
   - `SSH - Potential Brute Force`: runs daily by default
   - `Failed logon attempts in authpriv`: runs daily by default
   - `Multiple Password Reset by user`: runs daily by default. **Required for scenario 4.**
   - `SFTP File transfer above threshold`: runs every 15 min. **Required for scenario 5.**

   A rule that runs daily can take up to 24 h to raise an alert. For faster tests, edit
   the rule and set *Run query every* to 1 hour.
3. **For scenarios 2, 3 and 5 (SSH/SFTP):**
   - sshd is running on tekaden with password authentication allowed (`sudo systemctl start ssh`).
   - `sshpass` is installed on zura (`sudo apt install sshpass`).
   - fail2ban (if present) won't block zura during the test.
4. **For scenario 5 only:** sftp-server on tekaden logs file operations at INFO (one-time change):
   ```bash
   grep -n '^Subsystem' /etc/ssh/sshd_config      # check the current line first
   sudo sed -i 's|^Subsystem\s\+sftp\s\+.*|Subsystem sftp /usr/lib/openssh/sftp-server -l INFO|' /etc/ssh/sshd_config
   sudo sshd -t && sudo systemctl restart ssh
   ```

## Scenarios

| # | Situation | Run on | Rule(s) triggered | Threshold |
|---|---|---|---|---|
| 1 | Wrong sudo password ×12 | tekaden or zura | POC - Repeated sudo / SSH auth failures on Linux | >10 per host in 15 min |
| 2 | SSH brute force with an unknown user ×20 | zura → tekaden | SSH - Potential Brute Force<br>Failed logon attempts in authpriv<br>POC - Repeated sudo / SSH auth failures on Linux | >15 per IP+user in 4 h<br>≥15 per source IP<br>>10 per host in 15 min |
| 3 | SSH password guessing against a real user ×12 | zura → tekaden | POC - Repeated sudo / SSH auth failures on Linux | >10 per host in 15 min |
| 4 | Same account's password reset ×7 | tekaden or zura | Multiple Password Reset by user (must be enabled) | >5 per account |
| 5 | Bulk SFTP upload of 60 files | zura → tekaden | SFTP File transfer above threshold | ≥50 distinct files per user+IP in 15 min |

### 1. Wrong sudo password
```bash
for i in $(seq 12); do echo wrongpass | sudo -S -k -p '' true 2>/dev/null; done
```

### 2. SSH brute force with an unknown user
```bash
for i in $(seq 20); do
  sshpass -p wrongpass ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no nosuchuser@tekaden true
done
```

### 3. SSH password guessing against a real user
```bash
for i in $(seq 12); do
  sshpass -p wrongpass ssh -o StrictHostKeyChecking=no -o PubkeyAuthentication=no ronin@tekaden true
done
```

### 4. Repeated password resets
Creates a temporary local user, changes its password 7 times, then removes it.
```bash
sudo useradd -M sentinel-test
for i in $(seq 7); do echo "sentinel-test:Tmp-$RANDOM-Pw1" | sudo chpasswd; done
sudo userdel sentinel-test
```

### 5. Bulk SFTP transfer
Uploads 60 small files from zura to tekaden (prompts for ronin's password).
```bash
mkdir -p /tmp/sftp-test && for i in $(seq 60); do echo "$i" > /tmp/sftp-test/f$i.txt; done
sftp -o StrictHostKeyChecking=no ronin@tekaden <<'EOF'
mkdir sftp-test
cd sftp-test
lcd /tmp/sftp-test
mput *
EOF
```
Cleanup: `rm -rf /tmp/sftp-test` on zura, and `rm -rf ~/sftp-test` on tekaden.

## Not possible from these agents

- **POC - Multiple failed Windows logons from one host**: needs a Windows machine
  with AMA and the Windows DCR linked (`associate_arc_machines = true`).
- **POC - FortiGate repeated admin login failures**: needs a real FortiGate sending
  CEF to voltron.
- **Advanced Multistage Attack Detection (Fusion)**: correlates alerts from multiple
  Microsoft security products.
- **Other Microsoft Syslog templates**: Squid proxy and threat-intelligence templates
  need a Squid proxy or a TI feed. The Entra ID "failed logon / successful logon"
  templates need Entra ID sign-in logs, which this workspace doesn't collect.

## Verification

1. **Logs arrived** (2–10 min):
   ```kusto
   Syslog
   | where TimeGenerated > ago(30m) and Facility in ("auth", "authpriv")
   | project TimeGenerated, Computer, ProcessName, SyslogMessage
   | sort by TimeGenerated desc
   ```
2. **Alerts fired** (after the rule's next run: 15 min for SFTP, 1 h for the POC rule,
   up to 24 h for the templates that run daily):
   ```kusto
   SecurityAlert
   | where TimeGenerated > ago(1d)
   | summarize Alerts = count(), Last = max(TimeGenerated) by AlertName
   ```
3. **Incidents**: look under Sentinel → Incidents. You get one incident per alert,
   named after the rule.
