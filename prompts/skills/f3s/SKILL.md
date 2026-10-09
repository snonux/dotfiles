---
name: f3s
description: "Reference skill for the whole f3s homelab: FreeBSD f-hosts (f0-f3), bhyve Rocky VMs (r0-r2, rocky), WireGuard mesh, storage (ZFS, zrepl, CARP, NFS), the k3s cluster, observability, hosted workloads (Immich, Garage, Player, yChat, Forgejo, Miniflux news, irregular.ninja), Gogios, the OpenWrt router, Raspberry Pis (pi0-pi3), DTail/dserver, the pkgrepo, and the rocky VM. Use for any f3s host, network, storage, cluster, or app question. Triggers on: f3s, homelab, f0, r0, k3s, zrepl, CARP, NFS, pkgrepo, dserver, Pi-hole, JetKVM, rocky VM, miniflux, RSS news, gogios, openwrt, irregular ninja."
disable-model-invocation: true
---

# f3s Homelab Reference

**f3s** = **f**reeBSD + **k3s**. Four physical Beelink S12 Pro mini-PCs (Intel N100) running FreeBSD as the base OS. f0/f1/f2 each host a Rocky Linux 9 bhyve VM forming a 3-node HA k3s Kubernetes cluster. f3 is a standalone host for bhyve VMs only — not part of the k3s cluster — and runs a plain Rocky Linux 9 VM named `rocky`. Four Raspberry Pi 3 nodes (pi0–pi3) serve the static site and Pi-hole.

This skill is loaded explicitly (`/f3s`); it is not auto-selected by the model.

## When to Use

- Troubleshooting the homelab cluster
- Making decisions about configuration, storage, networking, or workload placement
- Answering questions about how the setup works

## How to Navigate (three levels)

Load as little as the task needs:

1. **This file** — the area map and the canonical host/IP table. Often enough for "which host / which IP" questions.
2. **One area index** (`references/<area>.md`) — the area's overview, quick reference, and a one-line map of its topic files. Read exactly one, the one matching the task.
3. **One topic file** (`references/<area>/<topic>.md`) — the full procedure or runbook. Read only the topic the area index points to.

Do not read a whole area directory up front. Follow a cross-area link only when the task actually crosses areas.

## Areas

| Area index | Covers |
|------------|--------|
| [Physical hosts](references/hosts.md) | Beelink hardware, FreeBSD base setup and upgrades, UPS, Shelly plugs (fans, AC), JetKVM, console resolution, shutdown hangs, safe reboot, kernel panics |
| [bhyve VMs](references/vms.md) | vm-bhyve, the r0–r2 Rocky guests, NVMe disk fix, bootstrapping a new Rocky guest, the FreeBSD VM and backup-restore test on f3 |
| [Network](references/network.md) | WireGuard mesh (topology, per-OS setup, generator, troubleshooting), off-LAN access via fishfinger/blowfish, OpenWrt router DNS/DHCP repair |
| [Storage](references/storage.md) | ZFS (`zdata`), USB keys, zrepl, CARP VIP, NFS over stunnel, nfs-mount-monitor, backups, storage and thermal troubleshooting |
| [k3s cluster](references/k3s.md) | Install, kubeconfig, off-LAN kubectl, ingress (relayd, cert-manager), ArgoCD, etcd recovery, gonf r-node rollout |
| [Observability](references/observability.md) | Prometheus, Alloy/Loki/Tempo/Grafana state, alerting, FreeBSD node_exporter, Gogios deployment, network-traffic troubleshooting |
| [Workloads](references/workloads.md) | Immich, Garage (S3), Player, yChat, Forgejo, goprecords/uptimed, reading Miniflux news, refreshing the irregular.ninja photo album |
| [Raspberry Pis](references/raspberry-pi.md) | pi0/pi1 NetBSD static site (bozohttpd, npf, uptimed), pi2/pi3 Pi-hole and LAN wildcard DNS |
| [DTail / dserver](references/dtail.md) | dserver deployment and operations on port 2222 across Pis and r0–r2 |
| [Package repo](references/pkgrepo.md) | `pkgrepo.f3s.buetow.org`: repo layout, packaging workflow, DTail package, client setup, OpenBSD build VM |
| [rocky VM](references/rocky-vm.md) | The plain Rocky Linux VM on f3: bhyve config, SSH keys, git remotes, tooling, tmux, privileges, zrepl |

## Quick Reference: Host IPs

This table is the canonical host/IP inventory; every area links back here.

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
| pi0 | Raspberry Pi 3, **NetBSD 11.0** (evbarm-aarch64), static `f3s.buetow.org` backend | 192.168.1.125 | 192.168.2.203 |
| pi1 | Raspberry Pi 3, **NetBSD 11.0** (evbarm-aarch64), static `f3s.buetow.org` backend | 192.168.1.126 | 192.168.2.204 |
| pi2 | Raspberry Pi 3, Rocky Linux 9, Pi-hole (Docker, host net) | 192.168.1.127 | — |
| pi3 | Raspberry Pi 3, Rocky Linux 9, Pi-hole (Docker, host net) | 192.168.1.128 | — |

## Config Repository

All manifests and config: `https://github.com/snonux/conf` (directory: `f3s/`)
