# f3s Storage (area index)

Persistent storage for k3s is served via **NFS over stunnel** from the FreeBSD hosts, backed by **ZFS** (`zdata` pool) with **CARP** for high availability and **zrepl** for continuous replication.

Note: original plan was HAST, replaced by **zrepl** (ZFS send/receive) — more reliable, avoids the ZFS corruption during failover that HAST caused.

## When to Use

- Working on the homelab storage layer: ZFS pools/datasets, encryption, USB keys
- The removable `zusb` backup pool (quarterly load/unload, moving the USB disks between f-hosts)
- zrepl replication (f0→f1 nfsdata, f3→f2 VM), CARP failover, NFS-over-stunnel
- Diagnosing NFS mount problems, SUSPENDED pools, or thermal issues
- For the physical hosts, WireGuard mesh, and host/IP inventory this depends on, see the [hub](../SKILL.md), [Physical hosts](hosts.md) and [Network](network.md).

## Topic Files

- [ZFS Pools & Encryption](storage/zfs.md) — `zdata` pool, physical disks, USB-stored keys mounted by `f3skeys` (not `/etc/fstab`), encrypted datasets, boot-time key loading, pool feature flags / `zpool upgrade` state
- [USB Key Mounting](storage/usb-keys.md) — `f3skeys`, `/usr/local/sbin/f3s-mount-keys`, current `zfskeys_datasets` per f-host, and the removable quarterly `zusb` backup pool (raw key on `/keys/zusb.key`, manual `zusb-load`/`zusb-unload` on all f-hosts)
- [zrepl Replication](storage/zrepl.md) — `f0 → f1` nfsdata, `f3 → f2` freebsd VM, sink configs, replication liveness check (f0 cron canary on `/data/nfs/nfs.LIVE_CHECK`), troubleshooting, DL-state recovery
- [CARP HA VIP](storage/carp.md) — VIP `192.168.1.138`, `carpcontrol.sh`, mgmt script, auto-failback, SUSPENDED-pool limitation
- [NFS over stunnel](storage/nfs.md) — NFS server, mutual-TLS stunnel, Rocky client config, `/etc/fstab`, the earth roaming client and its expired-cert fix
- [nfs-mount-monitor](storage/nfs-mount-monitor.md) — systemd watchdog on r-nodes (mount/stat/write probes, fail counter, cordon-and-reboot escalation)
- [Troubleshooting](storage/troubleshooting.md) — NFS issues, ZFS pool SUSPENDED recovery, **thermal** troubleshooting (Beelink S12 Pro)
- [Backups & Local-Path](storage/backups.md) — S3 Glacier Deep Archive, AWS CLI setup on a FreeBSD host (pkg + `/root/.aws` symlink to `/opt/snonux/secrets/aws.credentials`), when to use `local-path` instead of NFS

## Storage Summary

| Layer | Technology | Role |
|-------|-----------|------|
| Block | M.2+2.5" SSD (f0/f1/f2) | Physical storage |
| Filesystem | ZFS (`zdata/enc`) | Data integrity, AES-256-GCM encryption |
| Replication | `zrepl` | Continuous ZFS replication f0→f1 (1min NFS, 10min VM) |
| HA | CARP VIP 192.168.1.138 | Automatic failover for NFS/stunnel |
| Network | NFS over stunnel | Encrypted shared storage, mutual TLS auth |
| Local-path | k3s local-path provisioner | Node-local storage for SQLite/cache workloads |
| LAN access | FreeBSD relayd on CARP VIP | TCP forwarding to k3s :80/:443 |
| Backup | S3 Glacier Deep Archive | Off-site encrypted backup |
| Removable backup | `zusb` raidz2 (4 × 1.8 TB USB-SATA) | Offline backup storage, plugged in ~quarterly; raw key on `/keys/zusb.key`, manual `zusb-load`/`zusb-unload` on all f-hosts |
