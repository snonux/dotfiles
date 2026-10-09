# WireGuard: per-OS setup, example configs and the mesh generator

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

(`pi0`/`pi1` used to follow this same setup but are now NetBSD — see the NetBSD section of [wireguard.md](wireguard.md) instead.)

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

## WireGuard Mesh Generator

Manually creating 8+ wg0.conf files is error-prone. A Ruby script automates this:

```sh
git clone https://github.com/snonux/wireguardmeshgenerator
cd wireguardmeshgenerator
bundle install
sudo dnf install -y wireguard-tools
```

Config file: `wireguardmeshgenerator.yaml` — defines all hosts, their LAN/WG IPs, SSH details, and excluded peers (infrastructure nodes exclude roaming clients).

The script generates all configs and can push them via SSH.

Current mesh-specific notes:

- `pi0` and `pi1` are defined in the generator's YAML as `os: NetBSD` and excluded from most non-gateway peers, so they only tunnel to `blowfish` and `fishfinger` (`rocky` is in their `exclude_peers`, mirroring rocky's own exclusion of the Pis)
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
