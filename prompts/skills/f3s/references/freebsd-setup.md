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

## Slow SSH Login / DNS Troubleshooting

If SSH logins take ~30 seconds, the cause is reverse DNS lookup timing out. Root cause on bhyve VMs: SLAAC (Router Advertisement RDNSS) injects an unreachable IPv6 nameserver into `/etc/resolv.conf` via `resolvconf`, and it's queried first.

### Proper fix: `/etc/resolvconf.conf`

Mark the VM's NIC as `private_interfaces` so SLAAC DNS is not added globally, and pin the IPv4 nameserver:

```sh
# On bhyve VMs — interface name is typically vtnet0
cat <<EOF | doas tee /etc/resolvconf.conf
# Statically configure nameserver; mark vtnet0 as private so SLAAC-provided
# IPv6 DNS (from Router Advertisement RDNSS) is not added globally.
name_servers="192.168.1.1"
private_interfaces="vtnet0"
EOF
doas resolvconf -u   # regenerate /etc/resolv.conf immediately
```

On **FreeBSD hosts** (f0–f3), the interface is `re0` instead of `vtnet0`.

### Belt-and-suspenders: disable reverse DNS in sshd

```sh
# In /etc/ssh/sshd_config: set UseDNS no
doas service sshd restart
```

This was observed on `freebsd.lan` (FreeBSD bhyve VM on f3): `/etc/resolv.conf` had only `fd22:c702:acb7::1` (IPv6, unreachable), causing a 30-second DNS timeout on every SSH login.

## Breaking Changes in 15.0 to Watch For
- **bhyve PCI BARs**: if VM fails to boot, add `pci.enable_bars='true'` to `/zroot/bhyve/rocky/rocky.conf`
- **NFS privileged ports**: FreeBSD 15.0 sets `nfs_reserved_port_only=YES` in `/etc/defaults/rc.conf`, which causes the nfsd rc script to set `vfs.nfsd.nfs_privport=1` at startup — blocking NFS clients connecting via stunnel (unprivileged ports). **Important**: setting `vfs.nfsd.nfs_privport=0` in `/etc/sysctl.conf` or `/boot/loader.conf` does NOT work because the nfsd rc script overrides it. The correct fix on **each f-host**: `doas sysrc nfs_reserved_port_only=NO`
- **WireGuard interface address**: FreeBSD 15.0 requires a prefix length when setting interface addresses. Add `/32` to IPv4 `Address` lines in `/usr/local/etc/wireguard/wg0.conf` (e.g. `Address = 192.168.2.130/32`). Without this, `service wireguard start` fails with "setting interface address without mask is no longer supported".

Current version: **FreeBSD 15.0-RELEASE** (as of Part 8, upgraded from 14.3).

## /etc/hosts

All four FreeBSD hosts, Rocky VMs, and the FreeBSD bhyve VM on f3 are in `/etc/hosts` on each node:
```
192.168.1.130 f0 f0.lan f0.lan.buetow.org
192.168.1.131 f1 f1.lan f1.lan.buetow.org
192.168.1.132 f2 f2.lan f2.lan.buetow.org
192.168.1.133 f3 f3.lan f3.lan.buetow.org
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

## ZFS Snapshot Policy

Snapshot creation and retention should be managed by zrepl, not `zfs-periodic`,
on the f0-f3 FreeBSD hosts. Do not configure `zfs-periodic` and `zrepl` to
snapshot the same ZFS filesystem.

`zfs-periodic` snapshot creation is disabled in `/etc/periodic.conf` on hosts
that previously used it:

```sh
daily_zfs_snapshot_enable="NO"
weekly_zfs_snapshot_enable="NO"
monthly_zfs_snapshot_enable="NO"
```

Local non-replicated datasets are covered by a zrepl `snap` job:

```sh
  - name: local_zfs_snapshots
    type: snap
    snapshotting:
      type: cron
      prefix: zrepl_local_
      cron: "0 3 * * *"
    pruning:
      keep:
        - type: regex
          regex: "^(daily|weekly|monthly)-.*"
        - type: regex
          regex: "^pre-.*"
        - type: grid
          grid: 14x1d | 6x30d
          regex: "^zrepl_local_.*"
```

The regex keep rules preserve older `zfs-periodic` and pre-upgrade snapshots
during the migration. zrepl-managed replication datasets are excluded from these
local snap jobs and remain owned by their push jobs.

## uptimed

Config at `/usr/local/mimecast/etc/uptimed.conf` — `LOG_MAXIMUM_ENTRIES=0` (keep all records forever).
Check with `uprecords`.

## Kernel Modules

### coretemp (CPU temperature)

`coretemp` provides real per-core die temps via Intel DTS. It is **not** loaded by default. Without it, `hw.acpi.thermal.tz0` is the only temperature source — it is often a constant lie (e.g. always 27.9°C) and cannot be used for thermal alerting.

All f-hosts have `coretemp_load="YES"` in `/boot/loader.conf` (added 2026-05-17). This persists the module across reboots so Prometheus node_exporter can scrape `dev.cpu.N.temperature` automatically.

To check:
```sh
sysctl dev.cpu | grep temperature   # per-core die temps (requires coretemp)
kldstat | grep coretemp             # verify module is loaded
grep coretemp /boot/loader.conf     # verify persistence
```

To add manually if missing:
```sh
doas kldload coretemp
echo 'coretemp_load="YES"' | doas tee -a /boot/loader.conf
```

## Shell

Default shell is `tcsh` (FreeBSD default). Run `rehash` after installing new packages for tcsh to find them.
