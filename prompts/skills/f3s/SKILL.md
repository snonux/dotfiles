---
name: f3s
description: "Hub reference skill for the f3s homelab—four Beelink S12 Pro hosts (f0/f1/f2/f3) running FreeBSD with Rocky Linux Bhyve VMs and a k3s Kubernetes cluster. f0/f1/f2 run r0/r1/r2 k3s nodes; f3 is standalone bhyve only (not part of k3s) and hosts the plain Rocky Linux VM named rocky; plus four Raspberry Pi 3 nodes (pi0–pi3). This hub owns the master host/IP inventory, the physical hosts, bhyve layer, power, WireGuard mesh, and off-LAN access; detailed subsystems live in sibling skills: f3s-storage, f3s-k3s, f3s-observability, f3s-workloads, f3s-raspberry-pi, f3s-dtail (also pkgrepo, rocky-vm-setup). Use for host/network/context questions or as the entry point to the f3s skill family."
---

# f3s Homelab Reference

**f3s** = **f**reeBSD + **k3s**. Four physical Beelink S12 Pro mini-PCs (Intel N100) running FreeBSD as the base OS. f0/f1/f2 each host a Rocky Linux 9 bhyve VM forming a 3-node HA k3s Kubernetes cluster. f3 is a standalone host for bhyve VMs only — not part of the k3s cluster — and runs a plain Rocky Linux 9 VM named `rocky`.

## When to Use

- Troubleshooting the homelab cluster
- Making decisions about configuration, storage, networking, or workload placement
- Answering questions about how the setup works

## Reference Files

This hub keeps the cross-cutting host/network references that every other f3s
skill links back to. Topic-specific detail lives in the sibling skills (see
"Related skills" below). Detailed reference documentation is in the `references/`
subfolder:

- [Hardware](references/hardware.md) — Beelink S12 Pro specs, network switch, IPs, MAC addresses, Wake-on-LAN
- [FreeBSD Setup](references/freebsd-setup.md) — Base OS install, packages, ZFS snapshots, configuration
- [UPS & Power](references/ups-power.md) — APC BX750MI, apcupsd config on f0/f1/f2
- [Console (HDMI/JetKVM) & Shutdown](references/console-jetkvm-shutdown.md) — FreeBSD 15.1 regressed console to vga 640x480 (fix `efi_max_resolution="1080p"` in loader.conf); JetKVM on f1, only 1080p captures; shutdown hang (`rc.shutdown` 90s watchdog → single-user → un-wakeable by WoL) from slow bhyve k3s guest stop — **mitigated 2026-06-28**: `rcshutdown_timeout="300"` set on f0/f1/f2 (vm-bhyve 1.7.3 has no `stop_timeout` lever); safe remote-reboot procedure (`vm stopall` then `reboot`)
- [Rocky Linux VMs](references/rocky-linux-vms.md) — Bhyve, vm-bhyve, VM config, NVMe disk fix; FreeBSD VM on f3 (migrated from f0)
- [f3 Rocky VM](references/f3-rocky-vm.md) — Plain Rocky Linux 9 VM on f3 (`rocky`, `192.168.1.123`), autostart policy, root SSH
- [Bootstrap Rocky bhyve VM](references/bootstrap-rocky-bhyve.md) — Runbook for creating a new plain Rocky Linux bhyve guest with unattended kickstart
- [WireGuard Mesh](references/wireguard.md) — Mesh topology, IP assignments, peer configs (the canonical WireGuard reference for the whole homelab)
- [Remote Access](references/remote-access.md) — reaching f-hosts, r-VMs, rocky, and Pis from outside the LAN via fishfinger/blowfish ProxyJump; user/key requirements per host type; f3 WireGuard caveat
- [Shelly Plug (Rack Fans)](references/shelly-plug.md) — **Shelly Plug M Gen 3** at **`192.168.1.28`** powering the rack fans; digest auth (`admin`), secret on **`/keys/shelly_plug.secret`** (f-hosts) / **`~/.shelly_plug`** (earth/Pis); boot-time auto-on rc.d service (**`f3s/freebsd-hosts/shelly-fans/`**), `wol-f3s` on/off integration, HTTP RPC API

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
| rocky | Plain Rocky Linux VM on f3 | 192.168.1.123 | 192.168.2.123 |
| blowfish | OpenBSD internet GW | — | 192.168.2.110 |
| fishfinger | OpenBSD internet GW | — | 192.168.2.111 |
| earth | Fedora laptop (roaming) | — | 192.168.2.200 |
| pixel7pro | Android (roaming) | — | 192.168.2.201 |
| f3s-storage-ha | CARP VIP (f0/f1) | 192.168.1.138 | — |
| pi0 | Raspberry Pi 3, **NetBSD 10.1** (evbarm-aarch64), static `f3s.buetow.org` backend | 192.168.1.125 | 192.168.2.203 |
| pi1 | Raspberry Pi 3, **NetBSD 10.1** (evbarm-aarch64), static `f3s.buetow.org` backend | 192.168.1.126 | 192.168.2.204 |
| pi2 | Raspberry Pi 3, Rocky Linux 9, Pi-hole (Docker, host net) | 192.168.1.127 | — |
| pi3 | Raspberry Pi 3, Rocky Linux 9, Pi-hole (Docker, host net) | 192.168.1.128 | — |

## Related skills

Detailed subsystems were carved out of this hub into focused sibling skills. Load
the one that matches the task; this hub stays the canonical home for the host/IP
table, physical hosts, WireGuard mesh, and off-LAN access that they all link back to.

- [`f3s-storage`](../f3s-storage/SKILL.md) — ZFS (`zdata`), zrepl, CARP VIP, NFS over stunnel, nfs-mount-monitor, USB keys, backups, storage troubleshooting
- [`f3s-k3s`](../f3s-k3s/SKILL.md) — k3s cluster install, off-LAN access, ingress, ArgoCD, etcd recovery, r-node Rex rollout
- [`f3s-observability`](../f3s-observability/SKILL.md) — Prometheus/Alloy/Loki/Tempo + alerting, FreeBSD node_exporter
- [`f3s-raspberry-pi`](../f3s-raspberry-pi/SKILL.md) — pi0/pi1 NetBSD static `f3s.buetow.org`/`snonux.foo` site (bozohttpd), pi2/pi3 Pi-hole + LAN wildcard DNS
- [`f3s-workloads`](../f3s-workloads/SKILL.md) — hosted apps: Immich, Garage, Player, yChat, goprecords/uptimed
- [`f3s-dtail`](../f3s-dtail/SKILL.md) — DTail/dserver deployment/ops (SSH port 2222)
- [`pkgrepo`](../pkgrepo/SKILL.md) — `pkgrepo.f3s.buetow.org`, repo layout, package publication, client repo config (incl. the `dtail` package build)
- [`rocky-vm-setup`](../rocky-vm-setup/SKILL.md) — the plain Rocky Linux VM on f3 (`rocky`, `192.168.1.123`): SSH keys, git remotes, tooling, zrepl, user privileges

## Config Repository

All manifests and config: `https://codeberg.org/snonux/conf` (directory: `f3s/`)
