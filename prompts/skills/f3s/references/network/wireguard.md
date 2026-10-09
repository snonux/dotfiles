# WireGuard Mesh Network

## Topology

Hybrid WireGuard topology connecting the f3s infrastructure mesh, two gateway-only Raspberry Pi backends, and two roaming clients.

**Infrastructure hosts** (full mesh — every host connects to every other):
- `f0`, `f1`, `f2`, `f3` — FreeBSD physical nodes (home LAN)
- `r0`, `r1`, `r2` — Rocky Linux Bhyve VMs
- `blowfish`, `fishfinger` — OpenBSD internet gateways (OpenBSD Amsterdam and Hetzner)

**Limited-peer nodes** (connect only to the gateways — not full mesh):
- `pi0` — **NetBSD 11.0** on Raspberry Pi 3 (`192.168.2.203`)
- `pi1` — **NetBSD 11.0** on Raspberry Pi 3 (`192.168.2.204`)

**Roaming clients** (connect only to gateways):
- `earth` — Fedora laptop (192.168.2.200)
- `pixel7pro` — Android phone (192.168.2.201)

Even `fN <-> rN` tunnels exist (technically redundant since the VM runs on the host) to keep config uniform.
`pi0` and `pi1` are not full-mesh peers; each has exactly 2 peers: `blowfish` and `fishfinger`.

`rocky` (`192.168.2.123`, the plain VM on f3) is also gateway-only: it peers with `blowfish`/`fishfinger` and excludes everything else. Exclusions must be symmetric in the generator YAML — until 2026-09-25 pi0/pi1 did not exclude `rocky`, so both carried a `rocky` peer that never handshaked (0 B received) because rocky had no matching peer.

### `pi0`/`pi1` (NetBSD): deployed userspace WireGuard

Historical evidence from 10.1: the `wg` kernel module did **not** ship in that evbarm-aarch64 module set (confirmed absent from all 249 modules under `/stand/evbarm/10.1/modules`, so `ifconfig wg0 create` failed outright). The deployed configuration continues to use pkgsrc's `wireguard-go` (userspace) + `wireguard-tools` (`wg` CLI only — no `wg-quick` in this package):

- Interface must be named `tunN` (`wireguard-go` on NetBSD requires this — `wg0` is rejected: "Interface name must be tun[0-9]*"). Used `tun0`.
- Bring the interface up **and address it** (`ifconfig tun0 inet <ip> <ip> netmask 255.255.255.255`) *before* starting `wireguard-go`, or its read loop dies immediately with `EHOSTDOWN` ("host is down") and does not retry.
- `wg setconf tun0 <conf>` takes the normal `[Interface]`/`[Peer]` format (including `PersistentKeepalive`, unlike native `wgconfig` which has no keepalive flag at all) — but strictly rejects wg-quick extensions like `Address`/`DNS` ("Line unrecognized"), so the config fed to it has neither; the interface address is applied separately via `ifconfig`.
- No `wg-quick` means **no automatic routes**: each peer's AllowedIPs needs an explicit `route add -inet <ip>/32 <local-tun-ip> -iface` (and `-inet6` for the v6 ones) — `wg` only does the crypto/routing decision inside the tunnel, not the OS route table.
- All of this is wired into a custom `/etc/rc.d/wireguard` script (there's no stock rc.d for this) since there's no native `ifconfig.wg0`/wg-quick integration to hook into.
- `wireguardmeshgenerator` (`~/git/wireguardmeshgenerator`) generates both the `tun0.conf` and the `/etc/rc.d/wireguard` script (routes included, derived from each host's peer list) for `os: NetBSD` entries, and installs/reloads them over SSH the same way it does for every other OS. `doas` on NetBSD resets `PATH` to exclude both `/usr/pkg/bin` (hence the per-host `wg_bin` override in the YAML) and `/usr/sbin` (hence the generator using a full path for `chown` there).

## WireGuard IP Assignments

| Host | WireGuard IPv4 | WireGuard IPv6 | Role |
|------|----------------|----------------|------|
| f0 | 192.168.2.130 | fd42:beef:cafe:2::130 | FreeBSD host |
| f1 | 192.168.2.131 | fd42:beef:cafe:2::131 | FreeBSD host |
| f2 | 192.168.2.132 | fd42:beef:cafe:2::132 | FreeBSD host |
| f3 | 192.168.2.133 | fd42:beef:cafe:2::133 | FreeBSD host (standalone bhyve) |
| r0 | 192.168.2.120 | fd42:beef:cafe:2::120 | Rocky VM (k3s node) |
| r1 | 192.168.2.121 | fd42:beef:cafe:2::121 | Rocky VM (k3s node) |
| r2 | 192.168.2.122 | fd42:beef:cafe:2::122 | Rocky VM (k3s node) |
| blowfish | 192.168.2.110 | fd42:beef:cafe:2::110 | OpenBSD internet GW |
| fishfinger | 192.168.2.111 | fd42:beef:cafe:2::111 | OpenBSD internet GW |
| pi0 | 192.168.2.203 | fd42:beef:cafe:2::203 | NetBSD 11.0 on Raspberry Pi 3 (limited-peer: blowfish/fishfinger) |
| pi1 | 192.168.2.204 | fd42:beef:cafe:2::204 | NetBSD 11.0 on Raspberry Pi 3 (limited-peer: blowfish/fishfinger) |
| rocky | 192.168.2.123 | fd42:beef:cafe:2::123 | Plain Rocky VM on f3 (limited-peer: blowfish/fishfinger) |
| earth | 192.168.2.200 | fd42:beef:cafe:2::200 | Fedora laptop (roaming) |
| pixel7pro | 192.168.2.201 | fd42:beef:cafe:2::201 | Android phone (roaming) |

**Listen port: 56709** (all hosts)

WireGuard hostnames: `<host>.wg0.wan.buetow.org` (e.g. `f0.wg0.wan.buetow.org`)

## /etc/hosts Entries for WireGuard

Add to `/etc/hosts` on each host (FreeBSD and Rocky Linux):

```
192.168.2.130 f0.wg0 f0.wg0.wan.buetow.org
192.168.2.131 f1.wg0 f1.wg0.wan.buetow.org
192.168.2.132 f2.wg0 f2.wg0.wan.buetow.org
192.168.2.133 f3.wg0 f3.wg0.wan.buetow.org
192.168.2.120 r0.wg0 r0.wg0.wan.buetow.org
192.168.2.121 r1.wg0 r1.wg0.wan.buetow.org
192.168.2.122 r2.wg0 r2.wg0.wan.buetow.org
192.168.2.110 blowfish.wg0 blowfish.wg0.wan.buetow.org
192.168.2.111 fishfinger.wg0 fishfinger.wg0.wan.buetow.org
192.168.2.203 pi0.wg0 pi0.wg0.wan.buetow.org
192.168.2.204 pi1.wg0 pi1.wg0.wan.buetow.org
fd42:beef:cafe:2::130 f0.wg0.wan.buetow.org
fd42:beef:cafe:2::131 f1.wg0.wan.buetow.org
fd42:beef:cafe:2::132 f2.wg0.wan.buetow.org
fd42:beef:cafe:2::133 f3.wg0.wan.buetow.org
fd42:beef:cafe:2::120 r0.wg0.wan.buetow.org
fd42:beef:cafe:2::121 r1.wg0.wan.buetow.org
fd42:beef:cafe:2::122 r2.wg0.wan.buetow.org
fd42:beef:cafe:2::110 blowfish.wg0.wan.buetow.org
fd42:beef:cafe:2::111 fishfinger.wg0.wan.buetow.org
fd42:beef:cafe:2::203 pi0.wg0.wan.buetow.org
fd42:beef:cafe:2::204 pi1.wg0.wan.buetow.org
```

## Traffic Flows

| Flow | Purpose |
|------|---------|
| fN ↔ rN | NFS storage (FreeBSD hosts serve NFS to VMs via stunnel) |
| rN ↔ blowfish/fishfinger | k3s service traffic via `relayd` |
| pi0/pi1 ↔ blowfish/fishfinger | static `f3s.buetow.org` backend traffic via `relayd` |
| fN ↔ blowfish/fishfinger | Remote management |
| rN ↔ rM | k3s intra-cluster traffic |
| fN ↔ fM | zrepl storage replication |
| earth/pixel7pro ↔ gateways | Remote access (all traffic routed through VPN) |
| earth ↔ fN/rN/rocky (via fishfinger) | Direct SSH from the VPN to mesh hosts (earth's IP added to the fishfinger peer AllowedIPs on those hosts; no ProxyJump needed) |
