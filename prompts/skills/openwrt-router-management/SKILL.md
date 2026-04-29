---
name: openwrt-router-management
description: Diagnose and repair OpenWrt router DNS, DHCP, and AP/bridge management issues without storing credentials.
---

## When to Use

- Troubleshooting an OpenWrt router that is reachable on the LAN but DNS lookups fail or intermittently refuse queries.
- Inspecting dnsmasq, network config, DHCP, or LuCI on a live OpenWrt box.
- Verifying whether an AP/bridge-style OpenWrt device has a valid upstream DNS path.
- Fixing cases where clients can reach the router, but the router returns `REFUSED`, `NOTIMP`, or `EDE: Not Ready` for DNS queries.

## Login Target

- Host: `192.168.1.101`
- User: `root`
- Password: not stored in this skill

## Instructions

1. Never store or embed passwords in the skill. If SSH access is needed, use key-based auth or ask the user for credentials at runtime.
2. Start with reachability and service checks:
   - `ping` the router
   - scan ports `22`, `53`, `80`, and `443`
   - query DNS directly against the router with `dig @<router-ip> <name>`
3. If DNS queries return `REFUSED` or `EDE: Not Ready`, inspect:
   - `/etc/config/dhcp`
   - `/etc/config/network`
   - `/etc/resolv.conf`
   - `/tmp/resolv.conf.d/resolv.conf.auto`
   - `logread`
4. Check whether the router is acting as an AP/bridge rather than a routed WAN gateway.
   - If there is no `wan` interface, the router may still have a default route via the upstream gateway.
   - In that case, dnsmasq still needs an explicit upstream DNS server to forward to.
5. If `resolv.conf.auto` is empty, add an upstream DNS server to the LAN interface in UCI, typically the upstream gateway address or a known resolver.
   - Example pattern: set `network.lan.dns` to the upstream gateway or resolver IP.
6. Reload the network stack and restart dnsmasq after any config change.
7. Verify the fix by checking:
   - dnsmasq is running
   - dnsmasq is listening on port `53`
   - `dig` or `nslookup` against the router returns `NOERROR`
   - the router itself can resolve a public name
8. If dnsmasq logs `cannot read /etc/dnsmasq.servers`, create an empty `/etc/dnsmasq.servers` file only when the generated dnsmasq config references `serversfile=/etc/dnsmasq.servers`.
9. Keep changes minimal:
   - prefer UCI edits over direct file edits
   - restart only the affected service
   - re-test the exact failing query after each change

## Common Findings

- `dnsmasq` can answer local names but refuse forwarded lookups when it has no upstream resolver.
- On AP-only OpenWrt devices, `/tmp/resolv.conf.d/resolv.conf.auto` may be empty until `network.lan.dns` is set.
- The generated dnsmasq config may still reference `/etc/dnsmasq.servers`; an empty file is sufficient to silence the warning if no custom server list is needed.
- A missing upstream DNS setting can look like a DNS outage even when the router is otherwise reachable and DHCP is working.
