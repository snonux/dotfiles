---
name: f3s-storage
description: Reference skill for the f3s homelab storage layer, ZFS (`zdata`), zrepl replication, CARP storage VIP (f0/f1, `f3s-storage-ha` 192.168.1.138), NFS over stunnel, the nfs-mount-monitor watchdog, USB key material, local-path/backups, and storage troubleshooting (incl. thermal). Use when working on homelab storage, ZFS/zrepl, NFS mounts, CARP failover, or disk issues. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# f3s Storage

Persistent storage for k3s is served via **NFS over stunnel** from the FreeBSD hosts, backed by **ZFS** (`zdata` pool) with **CARP** for high availability and **zrepl** for continuous replication.

Note: original plan was HAST, replaced by **zrepl** (ZFS send/receive) — more reliable, avoids the ZFS corruption during failover that HAST caused.

## When to Use

- Working on the homelab storage layer: ZFS pools/datasets, encryption, USB keys
- zrepl replication (f0→f1 nfsdata, f3→f2 VM), CARP failover, NFS-over-stunnel
- Diagnosing NFS mount problems, SUSPENDED pools, or thermal issues
- For the physical hosts, WireGuard mesh, and host/IP inventory this depends on, see the [`f3s`](../f3s/SKILL.md) hub skill.

## Reference Files

- [ZFS Pools & Encryption](references/zfs.md) — `zdata` pool, physical disks, USB-stored keys mounted by `f3skeys` (not `/etc/fstab`), encrypted datasets, boot-time key loading
- [USB Key Mounting](references/usb-keys.md) — `f3skeys`, `/usr/local/sbin/f3s-mount-keys`, and current `zfskeys_datasets` per f-host
- [zrepl Replication](references/zrepl.md) — `f0 → f1` nfsdata, `f3 → f2` freebsd VM, sink configs, troubleshooting, DL-state recovery
- [CARP HA VIP](references/carp.md) — VIP `192.168.1.138`, `carpcontrol.sh`, mgmt script, auto-failback, SUSPENDED-pool limitation
- [NFS over stunnel](references/nfs.md) — NFS server, mutual-TLS stunnel, Rocky client config, `/etc/fstab`
- [nfs-mount-monitor](references/nfs-mount-monitor.md) — systemd watchdog on r-nodes (mount/stat/write probes, fail counter, cordon-and-reboot escalation)
- [Troubleshooting](references/troubleshooting.md) — NFS issues, ZFS pool SUSPENDED recovery, **thermal** troubleshooting (Beelink S12 Pro)
- [Backups & Local-Path](references/backups.md) — S3 Glacier Deep Archive, when to use `local-path` instead of NFS

## Storage Summary

| Layer | Technology | Role |
|-------|-----------|------|
| Block | M.2+2.5" SSD (f0/f1) | Physical storage |
| Filesystem | ZFS (`zdata/enc`) | Data integrity, AES-256-GCM encryption |
| Replication | `zrepl` | Continuous ZFS replication f0→f1 (1min NFS, 10min VM) |
| HA | CARP VIP 192.168.1.138 | Automatic failover for NFS/stunnel |
| Network | NFS over stunnel | Encrypted shared storage, mutual TLS auth |
| Local-path | k3s local-path provisioner | Node-local storage for SQLite/cache workloads |
| LAN access | FreeBSD relayd on CARP VIP | TCP forwarding to k3s :80/:443 |
| Backup | S3 Glacier Deep Archive | Off-site encrypted backup |
