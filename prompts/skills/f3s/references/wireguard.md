# WireGuard Mesh Network

## Topology

Hybrid WireGuard topology connecting the f3s infrastructure mesh, two gateway-only Raspberry Pi backends, and two roaming clients.

**Infrastructure hosts** (full mesh — every host connects to every other):
- `f0`, `f1`, `f2`, `f3` — FreeBSD physical nodes (home LAN)
- `r0`, `r1`, `r2` — Rocky Linux Bhyve VMs
- `blowfish`, `fishfinger` — OpenBSD internet gateways (OpenBSD Amsterdam and Hetzner)

**Limited-peer nodes** (connect to the gateways, plus `rocky` — not full mesh):
- `pi0` — **NetBSD 10.1** on Raspberry Pi 3 (`192.168.2.203`)
- `pi1` — **NetBSD 10.1** on Raspberry Pi 3 (`192.168.2.204`) — converted after `pi0`, same procedure, both peers up successfully first try on `pi1` since the `pi0`-derived runbook already had all the gotchas baked in

**Roaming clients** (connect only to gateways):
- `earth` — Fedora laptop (192.168.2.200)
- `pixel7pro` — Android phone (192.168.2.201)

Even `fN <-> rN` tunnels exist (technically redundant since the VM runs on the host) to keep config uniform.
`pi0` and `pi1` are not full-mesh peers; each has exactly 3 peers: `blowfish`, `fishfinger`, and `rocky` (verified against both hosts' live configs — not gateway-only as older notes here claimed).

### `pi0`/`pi1` (NetBSD): no native `wg(4)`, use `wireguard-go` instead

The `wg` kernel module documented above does **not** ship in the evbarm-aarch64 10.1 module set (confirmed: absent from all 249 modules under `/stand/evbarm/10.1/modules`, so `ifconfig wg0 create` fails outright) — despite `wg(4)` being upstream NetBSD since 9.2, this platform/release combination just doesn't have it. Fixed with pkgsrc's `wireguard-go` (userspace) + `wireguard-tools` (`wg` CLI only — no `wg-quick` in this package) instead:

- Interface must be named `tunN` (`wireguard-go` on NetBSD requires this — `wg0` is rejected: "Interface name must be tun[0-9]*"). Used `tun0`.
- Bring the interface up **and address it** (`ifconfig tun0 inet <ip> <ip> netmask 255.255.255.255`) *before* starting `wireguard-go`, or its read loop dies immediately with `EHOSTDOWN` ("host is down") and does not retry.
- `wg setconf tun0 <conf>` takes the normal `[Interface]`/`[Peer]` format (including `PersistentKeepalive`, unlike native `wgconfig` which has no keepalive flag at all) — same keys/PSKs as the `wg-quick`-format file `wireguardmeshgenerator` already renders to `dist/pi0/etc/wireguard/wg0.conf`, just fed to a different tool.
- No `wg-quick` means **no automatic routes**: each peer's AllowedIPs needs an explicit `route add -inet <ip>/32 <local-tun-ip> -iface` (and `-inet6` for the v6 ones) — `wg` only does the crypto/routing decision inside the tunnel, not the OS route table.
- All of this is wired into a custom `/etc/rc.d/wireguard` script (there's no stock rc.d for this) since there's no native `ifconfig.wg0`/wg-quick integration to hook into.
- Follow-up not yet done: `wireguardmeshgenerator.rb` only branches on `os == 'Linux' | 'FreeBSD' | 'OpenBSD'` and always emits `wg-quick`-style files; `wireguardmeshgenerator.yaml`'s `pi0:`/`pi1:` entries still say `os: Linux` with a `systemctl reload wg-quick@wg0.service` `reload_cmd`. Until the generator gains NetBSD support, both nodes' WireGuard configs are manually-maintained exceptions that a future `--generate`/`--install` regen would otherwise clobber.

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
| pi0 | 192.168.2.203 | fd42:beef:cafe:2::203 | NetBSD 10.1 on Raspberry Pi 3 (limited-peer: blowfish/fishfinger/rocky) |
| pi1 | 192.168.2.204 | fd42:beef:cafe:2::204 | NetBSD 10.1 on Raspberry Pi 3 (limited-peer: blowfish/fishfinger/rocky) |
| earth | 192.168.2.200 | fd42:beef:cafe:2::200 | Fedora laptop (roaming) |
| pixel7pro | 192.168.2.201 | fd42:beef:cafe:2::201 | Android phone (roaming) |

**Listen port: 56709** (all hosts)

WireGuard hostnames: `<host>.wg0.wan.buetow.org` (e.g. `f0.wg0.wan.buetow.org`)

## FreeBSD Setup (f0, f1, f2, f3)

```sh
doas pkg install wireguard-tools
doas sysrc wireguard_interfaces=wg0
doas sysrc wireguard_enable=YES
doas mkdir -p /usr/local/etc/wireguard
doas touch /usr/local/etc/wireguard/wg0.conf
doas service wireguard start
doas wg show  # check public key and listen port
```

## Rocky Linux Setup (r0, r1, r2)

(`pi0`/`pi1` used to follow this same setup but are now NetBSD — see "`pi0`/`pi1` (NetBSD): no native `wg(4)`" above instead.)

```sh
dnf install -y wireguard-tools
mkdir -p /etc/wireguard
touch /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
systemctl disable firewalld

# Ensure wg-quick can read the config:
chown root:root /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf
restorecon /etc/wireguard/wg0.conf
```

On Rocky Linux 9, wrong ownership or SELinux labels on `/etc/wireguard/wg0.conf` will break `wg-quick@wg0` even when the config itself is valid.

## OpenBSD Setup (blowfish, fishfinger)

```sh
doas pkg_add wireguard-tools
doas mkdir /etc/wireguard
doas touch /etc/wireguard/wg0.conf
cat <<END | doas tee /etc/hostname.wg0
inet 192.168.2.110 255.255.255.0 NONE
up
!/usr/local/bin/wg setconf wg0 /etc/wireguard/wg0.conf
END
```

(Use `192.168.2.111` on fishfinger)

### OpenBSD pf.conf — NAT for roaming clients

```sh
# NAT for WireGuard clients to access internet
match out on vio0 from 192.168.2.0/24 to any nat-to (vio0)

# Allow inbound traffic on WireGuard interface
pass in on wg0

# Allow all UDP traffic on WireGuard port
pass in inet proto udp from any to any port 56709
```

Apply with: `doas pfctl -f /etc/pf.conf`

## Example wg0.conf (f0)

> **FreeBSD 15.0 note**: The IPv4 `Address` line **must** include a prefix length (e.g. `/32`). Without it, `service wireguard start` fails: "setting interface address without mask is no longer supported". The IPv6 address already has `/64` so is unaffected.

```
[Interface]
# f0.wg0.wan.buetow.org
Address = 192.168.2.130/32
Address = fd42:beef:cafe:2::130/64
PrivateKey = **************************
ListenPort = 56709

[Peer]
# f1.lan.buetow.org as f1.wg0.wan.buetow.org
PublicKey = **************************
PresharedKey = **************************
AllowedIPs = 192.168.2.131/32
Endpoint = 192.168.1.131:56709

[Peer]
# blowfish.buetow.org as blowfish.wg0.wan.buetow.org
PublicKey = **************************
PresharedKey = **************************
AllowedIPs = 192.168.2.110/32
Endpoint = 23.88.35.144:56709
PersistentKeepalive = 25

[Peer]
# fishfinger.buetow.org as fishfinger.wg0.wan.buetow.org
PublicKey = **************************
PresharedKey = **************************
AllowedIPs = 192.168.2.111/32
Endpoint = 46.23.94.99:56709
PersistentKeepalive = 25
# ... all other mesh peers ...
```

Notes:
- `PersistentKeepalive = 25` is required for peers behind NAT (blowfish/fishfinger/roaming clients)
- Infrastructure hosts (fN, rN) do NOT need keepalive for peers on the same LAN
- A PSK (preshared key) is used per-pair for extra security

## Roaming Client wg0.conf (pixel7pro / earth)

```
[Interface]
# pixel7pro.wg0.wan.buetow.org
Address = 192.168.2.201
PrivateKey = **************************
ListenPort = 56709
DNS = 1.1.1.1, 8.8.8.8

[Peer]
# blowfish.buetow.org
PublicKey = **************************
PresharedKey = **************************
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 23.88.35.144:56709
PersistentKeepalive = 25

[Peer]
# fishfinger.buetow.org
PublicKey = **************************
PresharedKey = **************************
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 46.23.94.99:56709
PersistentKeepalive = 25
```

Roaming clients route all traffic (`0.0.0.0/0`) through gateways and only **peer** to blowfish/fishfinger (they are not full-mesh members). By default they cannot be directly reached by mesh hosts, because no mesh host carries the roaming client's wg0 IP in any peer's `AllowedIPs` — so the mesh host has no return route and sends replies out its LAN interface, where they are lost.

### Direct SSH from a roaming client to mesh hosts (earth enhancement)

`earth` is an exception: its wg0 IP (`192.168.2.200/32`, `fd42:beef:cafe:2::200/128`) has been added to the **fishfinger** peer's `AllowedIPs` on `f0`, `f1`, `f2`, `r0`, `r1`, `r2`, and `rocky`, so those hosts route `192.168.2.200` back through `wg0` to fishfinger, which forwards to earth. This lets you SSH directly from earth over the VPN with no ProxyJump:

```sh
ssh paul@f0.wg0    # also f1.wg0, f2.wg0
ssh root@r0.wg0    # also r1.wg0, r2.wg0
ssh root@rocky.wg0
```

Constraints / notes:
- earth still only **peers** to the gateways — reachability is via gateway forwarding plus a return route on the mesh side, not a direct peer relationship.
- Returns go via **fishfinger only**, not blowfish. earth's `blowfish` peer ends up with `allowed ips: (none)` in the running config because both gateway peers are configured with `0.0.0.0/0, ::/0` and wg-quick can only install one default route (see the dual-`0.0.0.0/0` troubleshooting note below). Returns via blowfish would be dropped by earth.
- `pi0`/`pi1` are not yet reachable directly from earth; they need the same `.200` addition to their fishfinger peer if desired.
- This is currently a **manual, non-durable** change — it is reverted by any `wireguardmeshgenerator` regen because earth is in every infra host's `exclude_peers`. The durable version is tracked as generator `ask` tasks (`+reachableRoaming`); see the `wireguardmeshgenerator` project task list.

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

## Troubleshooting: `reload` vs `restart` When Adding New Peers

`service wireguard reload` (used by the mesh generator) updates peer config but **does NOT add routes** for new peers. After adding a new host to the mesh, the other hosts need a full restart to get the new routes:

```sh
# On each existing host that had a new peer added via reload:
doas service wireguard restart
```

**Symptom**: WireGuard handshake succeeds (both sides show `latest handshake`) but TCP/ICMP traffic doesn't flow — confirmed by `netstat -rn | grep 192.168.2.NNN` returning no results.

## WireGuard Mesh Generator

Manually creating 8+ wg0.conf files is error-prone. A Ruby script automates this:

```sh
git clone https://codeberg.org/snonux/wireguardmeshgenerator
cd wireguardmeshgenerator
bundle install
sudo dnf install -y wireguard-tools
```

Config file: `wireguardmeshgenerator.yaml` — defines all hosts, their LAN/WG IPs, SSH details, and excluded peers (infrastructure nodes exclude roaming clients).

The script generates all configs and can push them via SSH.

Current mesh-specific notes:

- `pi0` and `pi1` are defined in the generator's YAML as Rocky Linux hosts (now stale — both are NetBSD; the generator has no NetBSD support yet, see above) and excluded from most non-gateway peers, so they only tunnel to `blowfish`, `fishfinger`, and `rocky`
- Installed config ownership must be OS-specific:
  - Linux: `root:root`
  - BSD: `root:wheel`
- When `restorecon` exists, run it after installing Linux configs so SELinux labels on `/etc/wireguard/wg0.conf` are correct

### FreeBSD 15.0 fix applied to generator

`wireguardmeshgenerator.rb` line 151 was updated from `/24` to `/32` for FreeBSD hosts:

```ruby
# Before (broken on FreeBSD 15.0 — start fails with "setting interface address without mask"):
ipv4_with_mask = hosts[myself]['os'] == 'FreeBSD' ? "#{ipv4}/24" : ipv4
# After (correct):
ipv4_with_mask = hosts[myself]['os'] == 'FreeBSD' ? "#{ipv4}/32" : ipv4
```

Note: `reload` only reconfigures peers/PSKs — it does not change the running interface address. A `restart` is needed to pick up the address change if the interface is already running.

## Troubleshooting: Regenerated Keypair Breaks the Tunnel

If a host's wg0 PrivateKey (and PSKs) are regenerated out-of-band (e.g. OS reinstall) but the peer configs on the other side are not updated, handshakes silently fail: `wg show` shows `0 B received` on the client and `endpoint: (none), rx=0` for that peer on the gateway, even though packets leave the client (confirmed with `tcpdump` on the wifi interface). WireGuard drops initiations it cannot authenticate and emits nothing, so the symptom is one-way traffic with no replies.

All three must match on both sides:
- the client's **PublicKey** as configured in the gateway's peer block,
- the gateway's **PublicKey** as configured in the client's peer block (must equal `wg show wg0 public-key` on the gateway),
- the per-pair **PresharedKey** (must be identical on both sides).

When fixing this by hand, also update the `wireguardmeshgenerator` `keys/` directory (`keys/<host>/priv.key`, `pub.key`, `keys/psk/<sorted_pair>.key`) so a regen reproduces the live configs — otherwise the next `--generate`/`--install` reverts the fix. This is tracked as the generator `+credentials` task.

## Troubleshooting: Dual `0.0.0.0/0` on Roaming Clients

A roaming client config that gives `AllowedIPs = 0.0.0.0/0, ::/0` to **both** gateway peers (as the generator currently does for `gateway: true`) is only partially functional: wg-quick can install only one default route, so the second peer silently ends up with `allowed ips: (none)` in the running config and is **not** a real failover. On `earth`, `sudo wg show` shows fishfinger with `0.0.0.0/0, ::/0` and blowfish with `(none)`.

Consequence: all return traffic to earth must go via fishfinger (the peer earth actually accepts traffic from). This is why the direct-SSH return route is added to the fishfinger peer only. A proper fix (single primary gateway with failover, or `Table = off` with policy routing) is tracked as the generator `+roamingFailover` task.

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
