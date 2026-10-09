# f3s Network (area index)

The WireGuard mesh that ties the f-hosts, r-VMs, OpenBSD gateways, NetBSD Pis and
roaming clients together, and how to reach the homelab from outside the LAN. LAN
and WireGuard IPs are in the [hub table](../SKILL.md#quick-reference-host-ips).

## When to Use

- Mesh topology, IP assignments, or which peer talks to which
- Adding a peer, regenerating configs, or fixing a broken tunnel
- Reaching f-hosts, r-VMs, `rocky`, or the Pis while roaming
- The OpenWrt router answers on the LAN but DNS lookups fail

## Topic Files

- [WireGuard Mesh](network/wireguard.md) — topology, the NetBSD Pi userspace deployment note, IP assignments, `/etc/hosts` entries, traffic flows (the canonical WireGuard reference for the whole homelab)
- [WireGuard setup](network/wireguard-setup.md) — FreeBSD, Rocky Linux and OpenBSD setup (incl. pf NAT for roaming clients), example `wg0.conf` for f0 and for roaming clients, direct SSH from a roaming client, the mesh generator and its FreeBSD 15.0 fix
- [WireGuard troubleshooting](network/wireguard-troubleshooting.md) — `reload` vs `restart` when adding peers, a regenerated keypair breaking the tunnel, dual `0.0.0.0/0` on roaming clients
- [Remote Access](network/remote-access.md) — reaching f-hosts, r-VMs, rocky, and Pis from outside the LAN via fishfinger/blowfish ProxyJump; user/key requirements per host type; f3 WireGuard caveat

LAN router:

- [OpenWrt router](network/openwrt-router.md) — diagnosing and repairing DNS, DHCP and AP/bridge problems on the OpenWrt box at `192.168.1.101` (dnsmasq `REFUSED` / `EDE: Not Ready`, empty `resolv.conf.auto`, missing upstream DNS); no credentials stored

## Related Areas

- kubectl over WireGuard while roaming: [k3s — remote access](k3s/kubectl-remote-access.md)
- WireGuard on the NetBSD Pis (`wireguard-go`): [Raspberry Pis — NetBSD WireGuard](raspberry-pi/netbsd-wireguard.md)
- "Something is eating the network": [Observability — network triage](observability/network-triage.md)
- LAN wildcard DNS and Pi-hole: [Raspberry Pis](raspberry-pi.md)
