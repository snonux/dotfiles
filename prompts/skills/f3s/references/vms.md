# f3s bhyve VMs (area index)

The bhyve layer on the f-hosts: the Rocky Linux 9 guests r0/r1/r2 (k3s nodes on
f0/f1/f2) and the guests on f3. Host IPs are in the
[hub table](../SKILL.md#quick-reference-host-ips).

## When to Use

- vm-bhyve setup, VM config, or VM management commands on an f-host
- The NVMe disk emulation fix that etcd needs
- Creating a new Rocky Linux bhyve guest
- The FreeBSD VM on f3 and its backup-restore clone

## Topic Files

- [Rocky Linux VMs](vms/rocky-linux-vms.md) — Bhyve, vm-bhyve, VM config, install, autostart, SSH access, NVMe disk fix, VM management commands; FreeBSD VM on f3 (migrated from f0)
- [Bootstrap Rocky bhyve VM](vms/bootstrap-rocky-bhyve.md) — runbook for creating a new plain Rocky Linux bhyve guest with unattended kickstart
- [Backup Restore Test](vms/backup-restore-test.md) — f3 clone of `freebsd` → `backuprestoretest` (same IP; `backup` pool on `nda1`+`nda2` → `/backup`)

## Related Areas

- The plain `rocky` guest on f3 (bhyve config, tooling, privileges): [rocky VM](rocky-vm.md)
- What runs inside r0–r2: [k3s cluster](k3s.md); dserver on them: [DTail](dtail.md)
- Slow guest stop and host shutdown hangs: [Physical hosts](hosts.md)
- VM dataset replication (f3 → f2): [Storage — zrepl](storage/zrepl.md)
