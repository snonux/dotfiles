# FreeBSD Base Setup

## Installation (Part 2)

FreeBSD installed from boot-only ISO (`FreeBSD-14.x-RELEASE-amd64-bootonly.iso`) via USB stick, using the text installer.

Key choices during install:
- **Guided ZFS on root** (pool: `zroot`), unencrypted (boot without manual interaction)
- **Static IP** configuration (see hardware.md for IPs)
- SSH daemon, NTP server/sync, `powerd` (CPU freq scaling) enabled at boot
- User `paul` added to the `wheel` group (for `doas`)

## Keeping Up to Date

Patch level updates:
```sh
doas freebsd-update fetch
doas freebsd-update install
doas reboot
```

Version upgrade example (14.2 → 14.3):
```sh
doas freebsd-update fetch && doas freebsd-update install && doas reboot
doas freebsd-update -r 14.3-RELEASE upgrade
doas freebsd-update install && doas reboot
doas freebsd-update install
doas pkg update && doas pkg upgrade && doas reboot
```

Major version upgrade (14.3 → 15.0) — run one host at a time:
```sh
# Pre-upgrade: patch 14.3, snapshot ZFS, stop bhyve VM
doas freebsd-update fetch && doas freebsd-update install
doas pkg update && doas pkg upgrade
doas zfs snapshot -r zroot@pre-15.0-upgrade
doas vm stop rocky

# Upgrade sequence (three freebsd-update install passes required)
doas freebsd-update upgrade -r 15.0-RELEASE
doas freebsd-update install && doas reboot   # installs new kernel
doas freebsd-update install                  # installs new userland
doas pkg upgrade                             # required: ABI changed
doas freebsd-update install                  # removes old libraries
doas reboot

# Post-upgrade: start VM, verify k3s node rejoined
doas vm start rocky
# kubectl get nodes   (from laptop — node should be Ready)
```

Breaking changes in 15.0 to watch for:
- **bhyve PCI BARs**: if VM fails to boot, add `pci.enable_bars='true'` to `/zroot/bhyve/rocky/rocky.conf`
- **NFS privileged ports**: if NFS mounts break on r0/r1/r2, add `resvport` to Rocky Linux mount options or `--no-resvport` to NFS server flags

Current version: **FreeBSD 15.0-RELEASE** (as of Part 8, upgraded from 14.3).

## /etc/hosts

All three FreeBSD hosts and Rocky VMs are in `/etc/hosts` on each node:
```
192.168.1.130 f0 f0.lan f0.lan.buetow.org
192.168.1.131 f1 f1.lan f1.lan.buetow.org
192.168.1.132 f2 f2.lan f2.lan.buetow.org
192.168.1.120 r0 r0.lan r0.lan.buetow.org
192.168.1.121 r1 r1.lan r1.lan.buetow.org
192.168.1.122 r2 r2.lan r2.lan.buetow.org
```
WireGuard IPs are also added (see wireguard.md).

## Packages Installed

```sh
doas pkg install helix doas zfs-periodic uptimed
```

- **helix** (`hx`): preferred text editor
- **doas**: KISS `sudo` replacement from OpenBSD; config: `/usr/local/etc/doas.conf` (wheel users run as root)
- **zfs-periodic**: automatic ZFS snapshot tool
- **uptimed**: uptime tracking daemon

Additional packages added over time:
```sh
doas pkg install vm-bhyve bhyve-firmware   # Part 4 - bhyve VMs
doas pkg install wireguard-tools           # Part 5 - WireGuard
doas pkg install git go                    # Part 4 - benchmarking
```

## ZFS Snapshot Policy (zfs-periodic)

Configured in `/etc/periodic.conf` for the `zroot` pool:

```sh
# Daily: 7 snapshots kept
daily_zfs_snapshot_enable="YES"
daily_zfs_snapshot_pools="zroot"
daily_zfs_snapshot_keep="7"

# Weekly: 5 snapshots kept
weekly_zfs_snapshot_enable="YES"
weekly_zfs_snapshot_pools="zroot"
weekly_zfs_snapshot_keep="5"

# Monthly: 6 snapshots kept
monthly_zfs_snapshot_enable="YES"
monthly_zfs_snapshot_pools="zroot"
monthly_zfs_snapshot_keep="6"
```

Note: `zdata` pool (for NFS storage) is managed by `zrepl`, not `zfs-periodic`.

## uptimed

Config at `/usr/local/mimecast/etc/uptimed.conf` — `LOG_MAXIMUM_ENTRIES=0` (keep all records forever).
Check with `uprecords`.

## Shell

Default shell is `tcsh` (FreeBSD default). Run `rehash` after installing new packages for tcsh to find them.
