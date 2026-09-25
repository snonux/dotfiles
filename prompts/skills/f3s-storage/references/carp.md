# CARP: High-Availability VIP

CARP (Common Address Redundancy Protocol) provides **VIP 192.168.1.138** that floats between f0 (primary) and f1 (standby). The VIP is what NFS clients and the FreeBSD `relayd` ingress connect to, so only the current MASTER serves traffic.

All of the CARP layer on f0/f1 is managed by gonf (`gonf/freebsd/carp.go`,
`./gonf.sh cluster freebsd-hosts freebsd_carp_*`; task gk2, 2026-09-25):
the rc.conf alias line, `carp_load`, the devd rule, `carpcontrol.sh`, the
`carp` CLI and the auto-failback job. Do not hand-edit them. The sections below
describe what gonf renders. gonf never runs ifconfig/netif/carpcontrol.sh; the
rc.conf and loader.conf lines apply at the next boot, a devd rule change
restarts devd (does not affect CARP state).

## /etc/rc.conf configuration

Rendered by `freebsd_carp_rc_conf`; the password comes from the KeePass
entry `Infra/carp-vhid1-pass` (logical secret `freebsd-hosts/carp/vhid1.pass`,
see `gonf/secrets/README.md`), advskew from `freebsd.CarpNode` in
`gonf/cluster/cluster.go`.

The password was **rotated on 2026-09-25** (task 1l2): the value that the
blog post (part 6) and older notes show is no longer in use anywhere. The
current one lives only in the vault and in rc.conf on f0/f1. It must be at
most 19 plain alphanumeric chars: ifconfig copies the key with
`strlcpy(..., CARP_KEY_LEN=20)`, so anything longer is silently cut to 19.
Never pass it on a doas command line (doas logs the command to syslog) and
never use `ifconfig -k` without hashing its output.

### Rotating the password (live, no reboot, no failover)

While only one host has the new key, each side drops the other's adverts
("discarded for bad authentication" in `netstat -s -p carp`) and after
~3 s (3 x advbase) the BACKUP becomes MASTER too: dual-master, and f1's devd
hook would start NFS on its read-only replica. So:

1. Back up `~/Documents/Keepass/master.kdbx`, generate 19 alphanumeric
   chars, `foostore --backend keepass import <dir>/carp-vhid1-pass Infra force`
   with file content `password: <new>` plus a `Notes:` section (import
   replaces the whole entry, so carry the notes over). Verify by sha256.
2. On f1 only: `doas service devd stop` (same idea as f3sctl
   `carp-quiesce`; keep f0's devd running).
3. Apply on both hosts in the same second: pipe a script to
   `ssh fN 'doas -n sh'` that waits for a shared epoch second, then runs
   `ifconfig re0 vhid 1 [advskew N from rc.conf] pass <new>` (ifconfig
   fetches the current vhid settings and only changes what is given, so
   addresses/advbase stay). In 2026-09 both landed within 7 ms and no
   transition happened.
4. Verify: `ifconfig re0 | grep carp:` (f0 MASTER / f1 BACKUP), the
   bad-authentication counter stays 0, and the key hash:
   `ifconfig -k re0 | sed -n 's/.*key "\(.*\)".*/\1/p' | sha256` equals the
   vault's hash on both. If f1 stays MASTER:
   `doas ifconfig re0 vhid 1 state backup` on f1.
5. `doas service devd start` on f1.
6. `./gonf.sh -dry-run cluster freebsd-hosts freebsd_carp_rc_conf` (only
   `rc-conf-carp` would-change on f0/f1), apply, re-run: clean.

`netstat -s -p carp` on f1 shows a steadily growing "discarded for bad vhid"
count (~1/s, already ~11k before the rotation; f0 shows 0). It predates the
rotation and is unrelated to the key; cause not investigated.

```sh
# On f0 (default advskew=0, wins elections)
ifconfig_re0_alias0="inet vhid 1 pass YOURPASSWORD alias 192.168.1.138/32"

# On f1 (advskew=100, loses elections to f0)
ifconfig_re0_alias0="inet vhid 1 advskew 100 pass YOURPASSWORD alias 192.168.1.138/32"
```

## Load CARP module

`carp_load="YES"` in `/boot/loader.conf` (gonf `freebsd_carp_loader_conf`).
Immediately: `doas kldload carp`.

## /etc/hosts for CARP VIP

```
192.168.1.138 f3s-storage-ha f3s-storage-ha.lan f3s-storage-ha.lan.buetow.org
192.168.2.138 f3s-storage-ha.wg0 f3s-storage-ha.wg0.wan.buetow.org
```

## devd: CARP state change hook

Drop-in `/usr/local/etc/devd/carp.conf` on f0 and f1 (gonf
`freebsd_carp_devd_hook`, source `f3s/freebsd-hosts/carp/devd-carp.conf`).
Until 2026-09-25 the block was appended to `/etc/devd.conf`; gonf removed it
there (the file is stock again), so it never fires twice:

```
notify 0 {
    match "system"    "CARP";
    match "subsystem" "[0-9]+@[0-9a-z.]+";
    match "type"      "(MASTER|BACKUP)";
    action "/usr/local/bin/carpcontrol.sh $subsystem $type";
};
```

gonf restarts devd when the rule changes.

## carpcontrol.sh — start/stop NFS+stunnel on failover

Source of truth: `f3s/freebsd-hosts/carp/carpcontrol.sh`.

Installed on f0 and f1 as `/usr/local/bin/carpcontrol.sh` (0555 root:wheel)
by gonf `freebsd_carp_control`.

The script must call `/usr/local/sbin/f3s-mount-keys` before any
`zfs load-key` operation because `/keys` is not mounted by `/etc/fstab`; see
[USB Key Mounting](usb-keys.md).

## CARP management script (`/usr/local/bin/carp`)

Source: `f3s/freebsd-hosts/carp/carp`, deployed to f0/f1 by gonf
(`./gonf.sh cluster freebsd-hosts freebsd_carp_script`). `carp state` prints the
bare state (MASTER/BACKUP/INIT) for scripts.

```sh
doas carp             # show current state
doas carp master      # force MASTER (e.g. reclaim after maintenance)
doas carp backup      # force BACKUP (trigger failover to f1)
doas carp auto-failback disable   # prevent auto-failback (for maintenance)
doas carp auto-failback enable    # re-enable auto-failback
```

## CARP failover limitation when ZFS is suspended

If f0's ZFS pool is SUSPENDED but f0's OS is still running, f0 remains CARP MASTER
(it keeps sending CARP advertisements). Attempts to manually demote f0 via:

```sh
doas carp backup                            # may return exit=0 but has no effect
doas ifconfig re0 vhid 1 state backup       # may return exit=1 silently
doas ifconfig re0 vhid 1 advskew 254        # may return exit=1 silently
```

…can all silently fail because the kernel has too many stuck IO threads blocking
the ifconfig ioctl path. The CARP VIP will **not** float to f1 in this case.
**Only a hard power cycle of f0 reliably triggers CARP failover.** See
[troubleshooting.md](troubleshooting.md) for the full SUSPENDED-pool recovery runbook.

## Auto-failback from f1 to f0

Source: `f3s/freebsd-hosts/carp/carp-auto-failback.sh`, deployed with its cron
job and newsyslog rotation by gonf (`freebsd_carp_*` tasks; do not hand-edit
root's crontab). It only promotes from a settled BACKUP (INIT during boot is
skipped) and logs a failed promotion to syslog at daemon.err.

Script `/usr/local/bin/carp-auto-failback.sh` runs every minute via cron on f0. Checks: currently BACKUP? `/data/nfs` mounted? Marker file exists? Failback not blocked? If all conditions met, promotes f0 to MASTER.

```sh
echo "* * * * * /usr/local/bin/carp-auto-failback.sh" | doas crontab -
doas touch /data/nfs/nfs.DO_NOT_REMOVE   # marker file required for auto-failback
```

Logs to `/var/log/carp-auto-failback.log`.
