---
name: f3s
description: Reference skill for the f3s homelab—four Beelink S12 Pro hosts (f0/f1/f2/f3) running FreeBSD with Rocky Linux Bhyve VMs and a k3s Kubernetes cluster. f0/f1/f2 run r0/r1/r2 k3s nodes; f3 is standalone bhyve only (not part of k3s). Also includes four Raspberry Pi 3 nodes (pi0–pi3) running Rocky Linux 9. Covers DTail/dserver on Pis (arm64) and k3s VMs (amd64). Use when troubleshooting or making configuration decisions for the f3s setup.
---

# f3s Homelab Reference

**f3s** = **f**reeBSD + **k3s**. Four physical Beelink S12 Pro mini-PCs (Intel N100) running FreeBSD as the base OS. f0/f1/f2 each host a Rocky Linux 9 bhyve VM forming a 3-node HA k3s Kubernetes cluster. f3 is a standalone host for bhyve VMs only — not part of the k3s cluster.

## When to Use

- Troubleshooting the homelab cluster
- Making decisions about configuration, storage, networking, or workload placement
- Answering questions about how the setup works

## Reference Files

Detailed reference documentation is in the `references/` subfolder:

- [Hardware](references/hardware.md) — Beelink S12 Pro specs, network switch, IPs, MAC addresses, Wake-on-LAN
- [FreeBSD Setup](references/freebsd-setup.md) — Base OS install, packages, ZFS snapshots, configuration
- [UPS & Power](references/ups-power.md) — APC BX750MI, apcupsd config on f0/f1/f2
- [Rocky Linux VMs](references/rocky-linux-vms.md) — Bhyve, vm-bhyve, VM config, NVMe disk fix; FreeBSD VM on f3 (migrated from f0)
- [WireGuard Mesh](references/wireguard.md) — Mesh topology, IP assignments, peer configs
- [Storage](references/storage.md) — ZFS (zdata), CARP, NFS over stunnel, zrepl replication
- [k3s Setup](references/k3s-setup.md) — HA k3s cluster, etcd, node IPs, kubeconfig, ArgoCD
- [Observability](references/observability.md) — Prometheus, Grafana, Loki, Alloy, Tempo
- [Immich](references/immich.md) — Photo server deployment, job queue stats, troubleshooting
- [Garage](references/garage.md) — Garage cluster, edge domain routing, S3 bucket/key workflow, troubleshooting
- [DTail / dserver](references/dtail.md) — dserver: Pis **arm64** vs r0–r2 **amd64**, r-VM **root** + `root.authorized_keys` cache, firewalld **2222**, systemd timers
- [dserver.d](references/dserver.d) — index: links to **Rocky r-VM DTail** subsection and full **dtail.md**

Package repository details were split into the sibling `pkgrepo` skill. Use `pkgrepo` for `pkgrepo.f3s.buetow.org`, repo layout, package publication, and client repo configuration.

## Quick Reference: Host IPs

| Host | Role | LAN IP | WireGuard IP |
|------|------|--------|--------------|
| f0 | FreeBSD host | 192.168.1.130 | 192.168.2.130 |
| f1 | FreeBSD host | 192.168.1.131 | 192.168.2.131 |
| f2 | FreeBSD host | 192.168.1.132 | 192.168.2.132 |
| f3 | FreeBSD host (standalone bhyve, not k3s) | 192.168.1.133 | 192.168.2.133 |
| r0 | Rocky Linux VM on f0 | 192.168.1.120 | 192.168.2.120 |
| r1 | Rocky Linux VM on f1 | 192.168.1.121 | 192.168.2.121 |
| r2 | Rocky Linux VM on f2 | 192.168.1.122 | 192.168.2.122 |
| blowfish | OpenBSD internet GW | — | 192.168.2.110 |
| fishfinger | OpenBSD internet GW | — | 192.168.2.111 |
| earth | Fedora laptop (roaming) | — | 192.168.2.200 |
| pixel7pro | Android (roaming) | — | 192.168.2.201 |
| f3s-storage-ha | CARP VIP (f0/f1) | 192.168.1.138 | — |
| pi0 | Raspberry Pi 3, Rocky Linux 9, static `f3s.buetow.org` backend | 192.168.1.125 | 192.168.2.203 |
| pi1 | Raspberry Pi 3, Rocky Linux 9, static `f3s.buetow.org` backend | 192.168.1.126 | 192.168.2.204 |
| pi2 | Raspberry Pi 3, Rocky Linux 9 | 192.168.1.127 | — |
| pi3 | Raspberry Pi 3, Rocky Linux 9 | 192.168.1.128 | — |

## Raspberry Pi Nodes

Four Raspberry Pi 3 boards running Rocky Linux 9.2 (Blue Onyx) aarch64 from the SIG/AltArch image (`RockyLinuxRpi_9-latest.img.xz`). Each has:

- User `paul` with passwordless sudo and SSH key auth
- Static IP on eth0 via NetworkManager
- Hostname `piN.lan.buetow.org`
- Filesystem expanded with `rootfs-expand`
- Default `rocky` user still present (password: `rockylinux`)
- No GRUB — boots via Pi's native bootloader (`/boot/cmdline.txt`)
- Custom RPi kernel from the `rockyrpi` repo

Current role split:

- `pi0` and `pi1` serve static `f3s.buetow.org` content behind OpenBSD `relayd` over WireGuard
- `pi2` and `pi3` remain available for Pi-specific services and experiments

### lighttpd Configuration

Config file: `/etc/lighttpd/lighttpd.conf` (managed directly on pi0/pi1, not in a config repo)

- Document root: `/var/www/html`
- SSH access: `ssh paul@piN.lan.buetow.org -p 22`
- Host-based virtual hosting maps domains to subdirectories:
  - `snonux.foo` / `www.snonux.foo` → `/var/www/html/snonux`

**Why Host-based vhosts?** `relayd` on the OpenBSD frontends cannot rewrite URL paths. It forwards requests with the original path intact. To serve a subdirectory as root for a domain, lighttpd must remap the document root based on the `Host` header.

Example vhost block:
```
$HTTP["host"] =~ "^(www\.)?snonux\.foo$" {
  server.document-root = "/var/www/html/snonux"
}
```

**Note**: The pcre2 JIT warning (`no more memory`) on Pi 3 hardware is harmless — regex matching still works, just without JIT compilation.

## DTail (dserver)

Distributed log access over SSH on port **2222** (not sshd’s 22). **pi0–pi3**: cross-build **linux/arm64** + `DTAIL_NO_ZSTD=yes`. **r0–r2** (k3s Rocky VMs): **linux/amd64** only; install as **root** over SSH; **`dtail.json` must list `root` in `Server.Permissions.Users`**; mirror **`/root/.ssh/authorized_keys`** → `/var/run/dserver/cache/root.authorized_keys` because the key-cache script only walks `/home/*`. **firewalld**: open **2222/tcp**. Rebuild clients from current **dtail** `master` if the “trust these hosts” prompt still hangs (stdout pause bug fixed upstream).

Details: [references/dtail.md](references/dtail.md) (section **dserver on r0, r1, r2**).

## Config Repository

All manifests and config: `https://codeberg.org/snonux/conf` (directory: `f3s/`)
