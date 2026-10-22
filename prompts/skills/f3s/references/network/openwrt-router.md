# OpenWrt Router Management

## When to Use

- Troubleshooting an OpenWrt router that is reachable on the LAN but DNS lookups fail or intermittently refuse queries.
- Inspecting dnsmasq, network config, DHCP, or LuCI on a live OpenWrt box.
- Verifying whether an AP/bridge-style OpenWrt device has a valid upstream DNS path.
- Fixing cases where clients can reach the router, but the router returns `REFUSED`, `NOTIMP`, or `EDE: Not Ready` for DNS queries.

## Login Target

- Host: `192.168.1.101`
- User: `root`
- Password: not stored in this reference

## Instructions

1. Never store or embed passwords in this reference. If SSH access is needed, use key-based auth or ask the user for credentials at runtime.
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

## Security: internet-to-LAN IPv6 (qm3 / audit S1)

Do not assume this OpenWrt AP/bridge is the internet gateway. Read the
reviewable procedure at `~/git/conf/f3s/docs/router-ipv6-containment.md`
before changing firewall policy. Router configuration, service reloads and
other live changes require explicit user approval of the actual device and
exact diff; keep a second authenticated session and guarded rollback.

Read-only evidence on 2026-10-22:

- `192.168.1.1` is the controller's IPv4 default gateway. HTTP answers with
  title `GPON Home Gateway`; SSH TCP22 times out. Its OS and IPv6 firewall
  control plane have not been established. Do not describe it as OpenWrt
  without further evidence.
- `192.168.1.101` is confirmed as a TP-Link EAP615-Wall v1 running OpenWrt
  25.12.2. Its first-seen SSH host identity was accepted with
  `StrictHostKeyChecking=accept-new` (changed-key protection retained).
  Key-only root authentication fails, but a matching vault credential
  allowed read-only inspection using an inherited pipe for the password;
  no password was displayed or placed in arguments or files.
- This AP has default IPv4 route via `.1` on `br-lan`, no default IPv6
  route, and no `network.wan`/`network.wan6` interfaces. Its unused WAN zone
  (`firewall.@zone[1]`) already has `forward=REJECT`; its only forwarding
  section is LAN to WAN. Default ICMPv6 rules are present. The active nft
  forward chain dispatches only `br-lan` after established/related handling.
  No broad WAN-to-LAN permit was found on this AP. Do not change its unused
  WAN zone and claim public IPv6 containment; inspect the GPON gateway's
  actual IPv6 routing/firewall controls first.
- `br-lan` is a bridge over `lan0` through `lan3`; the live bridge also
  contains Wi-Fi interfaces `phy0-ap0` and `phy1-ap0`. No pending firewall
  UCI changes were present during inspection.
- Blowfish, using public `vio0` via `fe80::1%vio0`, can still connect to
  f0 TCP22/111/2049, r0 TCP22/111/6443/10250/9100, and pi2 TCP22/53/80 over
  their global IPv6 addresses. The repo runbook records exact addresses and
  commands. This is a live exposure baseline, not successful containment.
- LAN ULA ping works for r0/pi2. f0's ULA is already marked `detached` and
  does not answer that probe. Blowfish's `wg0` SSH probes to f0/r0 succeed.

Desired policy on the device that actually routes public IPv6: reject new
WAN-to-LAN IPv6 by default, remove broad IPv6 forwarding/accept exceptions,
and retain required default ICMPv6 forwarding and established return traffic.
Preserve LAN-to-WAN, LAN/ULA and WireGuard access. `wan6` may be a network
within zone `wan`, not a zone by that name. WAN zone `forward=REJECT` alone
does not override explicit accept/forwarding rules; inspect effective rules.
Do not disable IPv6 or indiscriminately drop ICMPv6. If the GPON gateway
enforces this path, use its supported firewall controls instead of editing
UCI on an AP that the traffic bypasses.

After obtaining access, record actual gateway/AP forwarding roles and the
exact relevant gateway rule identities before requesting approval. AP policy
was inspected, but no exact gateway rule diff, private router backup,
firewall reload or post-change test has been performed. No credential was
submitted to the unidentified GPON gateway. The task remains open.

Verification from blowfish must show a public route before probing each
freshly discovered f0/r0/pi2 global IPv6 address:

```sh
route -n get -inet6 "$address"
for port in 22 111 2049 6443 10250 9100; do
    if nc -6 -z -w3 "$address" "$port" >/dev/null 2>&1; then
        printf 'FAIL: public IPv6 TCP %s is reachable\n' "$port"
    else
        printf 'No public IPv6 TCP connection on %s\n' "$port"
    fi
done
```

OpenBSD `nc` takes one port per call. Also recheck pi2 TCP53/80 and the
audit-exposed dserver TCP2222; inspect router policy/counters for UDP and
other protocols. Repeat successful LAN/ULA and WireGuard probes before
confirming the rollback guard. Record dated results and any pre-existing
failures separately; unsuccessful TCP probes alone do not prove the router
blocked the traffic.
