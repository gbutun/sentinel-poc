# Point the network devices at the forwarder

`FWD_IP` = the on-prem forwarder's LAN address (the `onprem-fwd-01` Arc machine).

## Fortinet FortiGate — send CEF

CLI:

```
config log syslogd setting
    set status enable
    set server "FWD_IP"
    set port 514
    set mode udp
    set format cef
    set facility local7
end
```

- CEF lands in the **CommonSecurityLog** table (`DeviceVendor == "Fortinet"`).
- Install the **Fortinet FortiGate** solution from Content Hub for the parser,
  workbook, hunting queries and analytics-rule templates.
- Verify: `CommonSecurityLog | where DeviceVendor == "Fortinet" | take 10`

## Switch — plain syslog

Cisco IOS example (adjust for your vendor):

```
logging host FWD_IP transport udp port 514
logging trap informational
logging facility local6
```

- Lands in the **Syslog** table (`ProcessName` / `HostName` identify the device).
- Verify: `Syslog | where HostName != "" | summarize count() by HostName`

## Notes

- Facilities used above (`local6`/`local7`) must be within
  `network_syslog_facilities` in `terraform.tfvars`.
- Keep devices on UDP/TCP 514 to the forwarder only; the forwarder is the single
  egress point to Azure.
- For many devices later: put the forwarder(s) behind a VIP/load balancer and
  scale horizontally; the DCRs and Content Hub parsers are unchanged.
