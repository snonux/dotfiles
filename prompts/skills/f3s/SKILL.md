---
name: f3s
description: Reference skill for the f3s homelab—four Beelink S12 Pro hosts (f0/f1/f2/f3) running FreeBSD with Rocky Linux Bhyve VMs and a k3s Kubernetes cluster. f0/f1/f2 run r0/r1/r2 k3s nodes; f3 is standalone bhyve only (not part of k3s). Also includes four Raspberry Pi 3 nodes (pi0–pi3) running Rocky Linux 9. Use when troubleshooting or making configuration decisions for the f3s setup.
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
- [Package Repos](references/package-repos.md) — Custom FreeBSD/OpenBSD pkg repo served from k3s nginx pod
- [Immich](references/immich.md) — Photo server deployment, job queue stats, troubleshooting

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
| pi0 | Raspberry Pi 3, Rocky Linux 9 | 192.168.1.125 | — |
| pi1 | Raspberry Pi 3, Rocky Linux 9 | 192.168.1.126 | — |
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

## Config Repository

All manifests and config: `https://codeberg.org/snonux/conf` (directory: `f3s/`)
