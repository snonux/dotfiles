# WireGuard Mesh Network

## Topology

Full-mesh VPN network connecting all f3s infrastructure hosts plus two roaming clients.

**Infrastructure hosts** (full mesh — every host connects to every other):
- `f0`, `f1`, `f2`, `f3` — FreeBSD physical nodes (home LAN)
- `r0`, `r1`, `r2` — Rocky Linux Bhyve VMs
- `blowfish`, `fishfinger` — OpenBSD internet gateways (OpenBSD Amsterdam and Hetzner)

**Roaming clients** (connect only to gateways):
- `earth` — Fedora laptop (192.168.2.200)
- `pixel7pro` — Android phone (192.168.2.201)

Even `fN <-> rN` tunnels exist (technically redundant since the VM runs on the host) to keep config uniform.

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

```sh
dnf install -y wireguard-tools
mkdir -p /etc/wireguard
touch /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
systemctl disable firewalld

# Fix SELinux blocking WireGuard:
dnf install -y policycoreutils-python-utils
semanage permissive -a wireguard_t
reboot
```

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

Roaming clients route all traffic (`0.0.0.0/0`) through gateways, only connect to blowfish/fishfinger, and cannot be directly reached by LAN hosts.

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
fd42:beef:cafe:2::130 f0.wg0.wan.buetow.org
fd42:beef:cafe:2::131 f1.wg0.wan.buetow.org
fd42:beef:cafe:2::132 f2.wg0.wan.buetow.org
fd42:beef:cafe:2::133 f3.wg0.wan.buetow.org
fd42:beef:cafe:2::120 r0.wg0.wan.buetow.org
fd42:beef:cafe:2::121 r1.wg0.wan.buetow.org
fd42:beef:cafe:2::122 r2.wg0.wan.buetow.org
fd42:beef:cafe:2::110 blowfish.wg0.wan.buetow.org
fd42:beef:cafe:2::111 fishfinger.wg0.wan.buetow.org
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

### FreeBSD 15.0 fix applied to generator

`wireguardmeshgenerator.rb` line 151 was updated from `/24` to `/32` for FreeBSD hosts:

```ruby
# Before (broken on FreeBSD 15.0 — start fails with "setting interface address without mask"):
ipv4_with_mask = hosts[myself]['os'] == 'FreeBSD' ? "#{ipv4}/24" : ipv4
# After (correct):
ipv4_with_mask = hosts[myself]['os'] == 'FreeBSD' ? "#{ipv4}/32" : ipv4
```

Note: `reload` only reconfigures peers/PSKs — it does not change the running interface address. A `restart` is needed to pick up the address change if the interface is already running.

## Traffic Flows

| Flow | Purpose |
|------|---------|
| fN ↔ rN | NFS storage (FreeBSD hosts serve NFS to VMs via stunnel) |
| rN ↔ blowfish/fishfinger | k3s service traffic via `relayd` |
| fN ↔ blowfish/fishfinger | Remote management |
| rN ↔ rM | k3s intra-cluster traffic |
| fN ↔ fM | zrepl storage replication |
| earth/pixel7pro ↔ gateways | Remote access (all traffic routed through VPN) |
