# Storage

## Architecture Overview

Persistent storage for k3s is served via **NFS over stunnel** from the FreeBSD hosts, backed by **ZFS** (`zdata` pool) with **CARP** for high availability and **zrepl** for continuous replication.

Note: Original plan was HAST, replaced by **zrepl** (ZFS send/receive) — more reliable, avoids ZFS corruption during failover that HAST caused.

## Physical Disks

- **f0**: 512GB M.2 (OS/zroot) + Samsung SSD 870 EVO 1TB (zdata)
- **f1**: 512GB M.2 (OS/zroot) + Crucial CT1000BX500SSD1 1TB (zdata)
- **f2**: No second drive (no zdata pool)
- **f3**: 512GB M.2 (OS/zroot); no zdata pool yet (planned)

## ZFS: zdata Pool Setup

On f0 and f1, create the zdata pool on the second SSD:

```sh
# Pool setup (f0 and f1 only)
doas zpool create zdata ada1   # ada1 = second SSD
```

## SSD TRIM Configuration

All f-hosts run on consumer SATA SSDs without power-loss protection
(SanDisk Ultra 3D, Samsung 870 EVO, Crucial BX500). Without TRIM, the
SSD controller can't reclaim freed pages and write amplification
explodes — observed on f0 (2026-05-16) as txg sync times of 5-14
seconds (should be <100 ms) and per-op latency of 374 ms (should be
<5 ms on an SSD). The encrypted dataset makes this worse because
AES-256-GCM ciphertext is full-entropy and the controller can't
opportunistically reclaim space.

Enable `autotrim` on every pool on every f-host (`zdata` and `zroot`
on f0/f1/f2; `zroot` only on f3):

```sh
# Persisted in pool metadata — survives reboot
for pool in $(zpool list -H -o name); do
  doas zpool set autotrim=on "$pool"
done
```

After turning autotrim on for the first time (or on a pool that has
never been trimmed), run a one-shot pool-wide TRIM to catch up on all
the historical free space the controller has been managing blind:

```sh
for pool in $(zpool list -H -o name); do
  doas zpool trim "$pool"        # async; monitor with `zpool status -t`
done
```

Caveat: `zpool trim` runs at low ZFS priority. On a heavily-loaded
disk (active rsync, frequent zrepl snapshots, bhyve VM under load) it
can stall at 0% indefinitely because regular I/O never drains.
Quietening the workload first (kill rsync, raise zrepl `interval` from
`1m` to `15m`+, pause/cancel scrub) lets TRIM make progress; once
caught up, autotrim keeps it steady-state in the background.

Verify across the fleet:

```sh
for h in f0 f1 f2 f3; do
  printf '%-3s ' "$h"
  ssh "$h" "sh -c 'for p in \$(zpool list -H -o name); do \
    printf \"%s=%s \" \"\$p\" \"\$(zpool get -H -o value autotrim \$p)\"; \
    done; echo'"
done
```

## ZFS Encryption Keys (USB Key Storage)

Encryption keys are stored on USB flash drives (UFS-formatted, mounted at `/keys`).
All four hosts (f0/f1/f2/f3) have USB keys at `/dev/da0` mounted at `/keys`, each holding
all 8 key files as cross-host backups.

```sh
# Format and mount USB key (on each node)
doas newfs /dev/da0
echo '/dev/da0 /keys ufs rw 0 2' | doas tee -a /etc/fstab
doas mkdir /keys
doas mount /keys

# Generate keys (on f0, then copy to f1, f2, f3)
doas openssl rand -out /keys/f0.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f1.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f2.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f3.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f0.lan.buetow.org:zdata.key 32
doas openssl rand -out /keys/f1.lan.buetow.org:zdata.key 32
doas openssl rand -out /keys/f2.lan.buetow.org:zdata.key 32
doas openssl rand -out /keys/f3.lan.buetow.org:zdata.key 32
doas chown root /keys/* && doas chmod 400 /keys/*
# Copy to f1, f2, f3 via tarball
```

## ZFS Encryption Setup

```sh
# On f0 - create encrypted zdata dataset
doas zfs create -o encryption=on -o keyformat=raw \
  -o keylocation=file:///keys/f0.lan.buetow.org:zdata.key zdata/enc

# Create the NFS data dataset (replicated to f1)
doas zfs create zdata/enc/nfsdata
doas zfs set mountpoint=/data/nfs zdata/enc/nfsdata
doas mkdir -p /data/nfs/k3svolumes

# Encrypt Bhyve VM dataset (zroot/bhyve)
# Stop VMs first, rename old, create new encrypted, zfs send snapshot, then destroy old
doas vm stop rocky
doas zfs rename zroot/bhyve zroot/bhyve_old
doas zfs set mountpoint=/mnt zroot/bhyve_old
doas zfs snapshot zroot/bhyve_old/rocky@hamburger
doas zfs create -o encryption=on -o keyformat=raw \
  -o keylocation=file:///keys/f0.lan.buetow.org:bhyve.key zroot/bhyve
doas zfs send zroot/bhyve_old/rocky@hamburger | doas zfs recv zroot/bhyve/rocky
# Copy vm-bhyve metadata: .config, .img, .templates, .iso
doas zfs destroy -R zroot/bhyve_old
```

### Auto-load encryption keys on boot

```sh
# On f0
doas sysrc zfskeys_enable=YES
doas sysrc zfskeys_datasets="zdata/enc zdata/enc/nfsdata zroot/bhyve"

# On f1
doas sysrc zfskeys_enable=YES
doas sysrc zfskeys_datasets="zdata/enc zroot/bhyve zdata/sink/f0/zdata/enc/nfsdata"

# On f3 (bhyve VMs only, no zdata pool yet)
doas sysrc zfskeys_enable=YES
doas sysrc zfskeys_datasets="zroot/bhyve"
doas zfs set keylocation=file:///keys/f0.lan.buetow.org:zdata.key \
  zdata/sink/f0/zdata/enc/nfsdata
```

## zrepl: Continuous ZFS Replication (f0 → f1)

Install on both f0 and f1:
```sh
doas pkg install -y zrepl
```

### f0 configuration (`/usr/local/etc/zrepl/zrepl.yml`)

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: f0_to_f1_nfsdata
    type: push
    connect:
      type: tcp
      address: "192.168.2.131:8888"   # f1 WireGuard IP
    filesystems:
      "zdata/enc/nfsdata": true
    send:
      encrypted: true
    snapshotting:
      type: periodic
      prefix: zrepl_
      interval: 1m                    # every minute
    pruning:
      keep_sender:
        - type: last_n
          count: 10
        - type: grid
          grid: 24x1h | 14x1d | 6x30d
          regex: "^zrepl_.*"
      keep_receiver:
        - type: last_n
          count: 10
        - type: grid
          grid: 24x1h | 14x1d | 6x30d
          regex: "^zrepl_.*"

  # Note: f0_to_f1_freebsd job removed — the FreeBSD VM was migrated to f3.
  # It is now replicated from f3 → f2 (see f3 zrepl config below).
```

### f3 configuration (push: freebsd VM → f2)

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: f3_to_f2_freebsd
    type: push
    connect:
      type: tcp
      address: "192.168.2.132:8888"   # f2 WireGuard IP
    filesystems:
      "zroot/bhyve/freebsd": true     # development FreeBSD VM
    send:
      encrypted: true
    snapshotting:
      type: periodic
      prefix: zrepl_
      interval: 10m
    pruning:
      keep_sender:
        - type: last_n
          count: 10
        - type: grid
          grid: 24x1h | 14x1d
          regex: "^zrepl_.*"
      keep_receiver:
        - type: last_n
          count: 10
        - type: grid
          grid: 24x1h | 14x1d
          regex: "^zrepl_.*"
```

### f2 configuration (sink for f3's freebsd VM)

f2 has no second drive so the sink lives in `zroot/sink`:

```sh
doas zfs create zroot/sink
```

`/usr/local/etc/zrepl/zrepl.yml`:

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: sink
    type: sink
    serve:
      type: tcp
      listen: "192.168.2.132:8888"    # f2 WireGuard IP
      clients:
        "192.168.2.133": "f3"
    recv:
      placeholder:
        encryption: inherit
    root_fs: "zroot/sink"
```

Replicated path: `zroot/bhyve/freebsd` → `zroot/sink/f3/zroot/bhyve/freebsd`

Important: do not let `zfs-periodic` snapshot zrepl-managed sender or receiver
datasets. Snapshot creation should be owned by zrepl. On f2,
`/etc/periodic.conf` disables `zfs-periodic` snapshot creation:

```sh
daily_zfs_snapshot_enable="NO"
weekly_zfs_snapshot_enable="NO"
monthly_zfs_snapshot_enable="NO"
```

The local zrepl `snap` job on f2 also explicitly excludes `zroot/sink<`.

### f1 configuration (sink)

```sh
doas zfs create zdata/sink   # receive dataset
```

`/usr/local/etc/zrepl/zrepl.yml`:

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: sink
    type: sink
    serve:
      type: tcp
      listen: "192.168.2.131:8888"
      clients:
        "192.168.2.130": "f0"
    recv:
      placeholder:
        encryption: inherit
    root_fs: "zdata/sink"
```

### Enable and start

```sh
doas sysrc zrepl_enable=YES
doas service zrepl start
doas zrepl status   # monitor replication
```

Replicated paths: `zdata/enc/nfsdata` → `zdata/sink/f0/zdata/enc/nfsdata`

### Mount replica on f1 (read-only standby)

```sh
doas zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key \
  zdata/sink/f0/zdata/enc/nfsdata
doas mkdir -p /data/nfs
doas zfs set mountpoint=/data/nfs zdata/sink/f0/zdata/enc/nfsdata
doas zfs mount zdata/sink/f0/zdata/enc/nfsdata
doas zfs set readonly=on zdata/sink/f0/zdata/enc/nfsdata   # prevent replication breakage
```

### Failover design: intentionally read-only replica

The standby replica is read-only by design. Manual failover (not automatic) to prevent split-brain. To fix broken replication after accidental writes: `doas zfs rollback <snapshot>`.

### zrepl troubleshooting

```sh
# Signal manual replication
doas zrepl signal wakeup f0_to_f1_nfsdata

# Fix "no common snapshot" — destroy and re-replicate
doas zfs destroy -r zdata/sink/f0/zdata/enc/nfsdata

# Test network connectivity
nc -zv 192.168.2.131 8888

# Monitor progress
doas zrepl status --mode raw | grep BytesReplicated
```

**zrepl DL-state on f1 after mid-replication f0 reboot**: if f0 reboots while zrepl is
actively replicating, f1's `[zfskern]` thread can enter **DL state** (disk + locked).
Symptoms: `zpool list`, `zfs list`, `ls /data/nfs/` all hang indefinitely; `zfs set
readonly=off` may return immediately (the kernel path differs). To recover on f1:

```sh
# Stop zrepl to release the replication lock
doas service zrepl stop

# Wait ~30–60 s for the kernel state to drain; then verify
doas zpool list
doas zfs list
doas service zrepl start
```

If ZFS commands still hang after stopping zrepl, a reboot of f1 is required.
The NFS data is still available on f0 so k3s is unaffected during f1 recovery.

## CARP: High-Availability VIP

CARP (Common Address Redundancy Protocol) provides **VIP 192.168.1.138** that floats between f0 (primary) and f1 (standby).

### /etc/rc.conf configuration

```sh
# On f0 (default advskew=0, wins elections)
ifconfig_re0_alias0="inet vhid 1 pass YOURPASSWORD alias 192.168.1.138/32"

# On f1 (advskew=100, loses elections to f0)
ifconfig_re0_alias0="inet vhid 1 advskew 100 pass YOURPASSWORD alias 192.168.1.138/32"
```

### Load CARP module

```sh
echo 'carp_load="YES"' | doas tee -a /boot/loader.conf
# or immediately: doas kldload carp
```

### /etc/hosts for CARP VIP

```
192.168.1.138 f3s-storage-ha f3s-storage-ha.lan f3s-storage-ha.lan.buetow.org
192.168.2.138 f3s-storage-ha.wg0 f3s-storage-ha.wg0.wan.buetow.org
```

### devd: CARP state change hook

Add to `/etc/devd.conf` on f0 and f1:

```
notify 0 {
    match "system"    "CARP";
    match "subsystem" "[0-9]+@[0-9a-z.]+";
    match "type"      "(MASTER|BACKUP)";
    action "/usr/local/bin/carpcontrol.sh $subsystem $type";
};
```

```sh
doas service devd restart
```

### carpcontrol.sh — start/stop NFS+stunnel on failover

```sh
#!/bin/sh
HOSTNAME=`hostname`

if [ ! -f /data/nfs/nfs.DO_NOT_REMOVE ]; then
    logger '/data/nfs not mounted, mounting it now!'
    if [ "$HOSTNAME" = 'f0.lan.buetow.org' ]; then
        zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key zdata/enc/nfsdata
        zfs set mountpoint=/data/nfs zdata/enc/nfsdata
    else
        zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key zdata/sink/f0/zdata/enc/nfsdata
        zfs set mountpoint=/data/nfs zdata/sink/f0/zdata/enc/nfsdata
        zfs mount zdata/sink/f0/zdata/enc/nfsdata
        zfs set readonly=on zdata/sink/f0/zdata/enc/nfsdata
    fi
    service nfsd stop 2>&1
    service mountd stop 2>&1
fi

case "$2" in
    MASTER)
        logger "CARP state changed to MASTER, starting services"
        service rpcbind start >/dev/null 2>&1
        service mountd start >/dev/null 2>&1
        service nfsd start >/dev/null 2>&1
        service nfsuserd start >/dev/null 2>&1
        service stunnel restart >/dev/null 2>&1
        ;;
    BACKUP)
        logger "CARP state changed to BACKUP, stopping services"
        service stunnel stop >/dev/null 2>&1
        service nfsd stop >/dev/null 2>&1
        service mountd stop >/dev/null 2>&1
        service nfsuserd stop >/dev/null 2>&1
        ;;
esac
```

Install: `doas chmod +x /usr/local/bin/carpcontrol.sh` (copy to f1 too)

### CARP management script (`/usr/local/bin/carp`)

```sh
doas carp             # show current state
doas carp master      # force MASTER (e.g. reclaim after maintenance)
doas carp backup      # force BACKUP (trigger failover to f1)
doas carp auto-failback disable   # prevent auto-failback (for maintenance)
doas carp auto-failback enable    # re-enable auto-failback
```

### CARP failover limitation when ZFS is suspended

If f0's ZFS pool is SUSPENDED but f0's OS is still running, f0 remains CARP MASTER
(it keeps sending CARP advertisements). Attempts to manually demote f0 via:

```sh
doas carp backup                            # may return exit=0 but has no effect
doas ifconfig re0 vhid 1 state backup       # may return exit=1 silently
doas ifconfig re0 vhid 1 advskew 254        # may return exit=1 silently
```

…can all silently fail because the kernel has too many stuck IO threads blocking
the ifconfig ioctl path. The CARP VIP will **not** float to f1 in this case.
**Only a hard power cycle of f0 reliably triggers CARP failover.**

### Auto-failback from f1 to f0

Script `/usr/local/bin/carp-auto-failback.sh` runs every minute via cron on f0. Checks: currently BACKUP? `/data/nfs` mounted? Marker file exists? Failback not blocked? If all conditions met, promotes f0 to MASTER.

```sh
echo "* * * * * /usr/local/bin/carp-auto-failback.sh" | doas crontab -
doas touch /data/nfs/nfs.DO_NOT_REMOVE   # marker file required for auto-failback
```

Logs to `/var/log/carp-auto-failback.log`.

## NFS Server Configuration (f0 and f1)

```sh
doas sysrc nfs_server_enable=YES
doas sysrc nfsv4_server_enable=YES
doas sysrc nfsuserd_enable=YES
doas sysrc nfsuserd_flags="-domain lan.buetow.org"
doas sysrc mountd_enable=YES
doas sysrc rpcbind_enable=YES
doas sysrc nfs_reserved_port_only=NO   # Required for NFS over stunnel (unprivileged ports)

doas mkdir -p /data/nfs/k3svolumes
doas chmod 755 /data/nfs/k3svolumes
```

> **FreeBSD 15.0 note**: FreeBSD 15.0 sets `nfs_reserved_port_only=YES` by default in `/etc/defaults/rc.conf`. The nfsd rc script (`/etc/rc.d/nfsd`) checks this variable and explicitly runs `sysctl vfs.nfsd.nfs_privport=1` at startup, overriding any value set in `/etc/sysctl.conf` or `/boot/loader.conf`. This blocks NFS clients connecting via stunnel (unprivileged ports). Fix on **each f-host**:
> ```sh
> # The ONLY correct fix — setting sysctl.conf does NOT work
> doas sysrc nfs_reserved_port_only=NO
> # Apply immediately without reboot
> doas sysctl vfs.nfsd.nfs_privport=0
> # Remount on each r-host
> mount -a
> ```

`/etc/exports` (stunnel clients appear as localhost):

```
V4: /data/nfs -sec=sys
/data/nfs -alldirs -maproot=root -network 127.0.0.1 -mask 255.255.255.255
```

Start services:

```sh
doas service rpcbind start
doas service mountd start
doas service nfsd start
doas service nfsuserd start
```

## stunnel: Encrypted NFS over TLS

stunnel binds to the CARP VIP (192.168.1.138), so only the CARP MASTER accepts connections. Uses mutual TLS with client certificate authentication.

### Create CA and certificates (on f0)

```sh
doas mkdir -p /usr/local/etc/stunnel/ca
cd /usr/local/etc/stunnel/ca
doas openssl genrsa -out ca-key.pem 4096
doas openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem \
  -subj '/C=US/ST=State/L=City/O=F3S Storage/CN=F3S Stunnel CA'

cd /usr/local/etc/stunnel
doas openssl genrsa -out server-key.pem 4096
doas openssl req -new -key server-key.pem -out server.csr \
  -subj '/C=US/ST=State/L=City/O=F3S Storage/CN=f3s-storage-ha.lan'
doas openssl x509 -req -days 3650 -in server.csr -CA ca/ca-cert.pem \
  -CAkey ca/ca-key.pem -CAcreateserial -out server-cert.pem

# Client certs for r0, r1, r2, earth
for client in r0 r1 r2 earth; do
  openssl genrsa -out ca/${client}-key.pem 4096
  openssl req -new -key ca/${client}-key.pem -out ca/${client}.csr \
    -subj "/C=US/ST=State/L=City/O=F3S Storage/CN=${client}.lan.buetow.org"
  openssl x509 -req -days 3650 -in ca/${client}.csr -CA ca/ca-cert.pem \
    -CAkey ca/ca-key.pem -CAcreateserial -out ca/${client}-cert.pem
  cat ca/${client}-cert.pem ca/${client}-key.pem > ca/${client}-stunnel.pem
done
```

### stunnel server config (`/usr/local/etc/stunnel/stunnel.conf`)

```
cert = /usr/local/etc/stunnel/server-cert.pem
key = /usr/local/etc/stunnel/server-key.pem
setuid = stunnel
setgid = stunnel

[nfs-tls]
accept = 192.168.1.138:2323
connect = 127.0.0.1:2049
CAfile = /usr/local/etc/stunnel/ca/ca-cert.pem
verify = 2
requireCert = yes
```

```sh
doas pkg install -y stunnel
doas sysrc stunnel_enable=YES
doas service stunnel start
# Copy certs to f1 via tarball, configure identically
```

## NFS Client Configuration (Rocky Linux r0, r1, r2)

```sh
dnf install -y stunnel nfs-utils

# Copy client cert and CA from f0
scp f0:/usr/local/etc/stunnel/ca/r0-stunnel.pem /etc/stunnel/
scp f0:/usr/local/etc/stunnel/ca/ca-cert.pem /etc/stunnel/
```

`/etc/stunnel/stunnel.conf` (r0 example):

```
cert = /etc/stunnel/r0-stunnel.pem
CAfile = /etc/stunnel/ca-cert.pem
client = yes
verify = 2

[nfs-ha]
accept = 127.0.0.1:2323
connect = 192.168.1.138:2323
```

```sh
systemctl enable --now stunnel
```

### NFSv4 user mapping

`/etc/idmapd.conf` on r0, r1, r2:

```
[General]
Domain = lan.buetow.org
```

Fix inotify limit:

```sh
echo 'fs.inotify.max_user_instances = 512' > /etc/sysctl.d/99-inotify.conf
sysctl -w fs.inotify.max_user_instances=512
systemctl enable --now nfs-client.target nfs-idmapd
```

### Mount NFS

```sh
mkdir -p /data/nfs/k3svolumes
mount -t nfs4 -o port=2323 127.0.0.1:/k3svolumes /data/nfs/k3svolumes
```

`/etc/fstab`:

```
127.0.0.1:/k3svolumes /data/nfs/k3svolumes nfs4 port=2323,_netdev,hard,timeo=600,retrans=3 0 0
```

NFS path structure on k3s nodes: `/data/nfs/k3svolumes/<app>/`

## NFS Troubleshooting

### All r-nodes show "access denied" when mounting NFS

**Most likely cause**: `vfs.nfsd.nfs_privport=1` on the CARP MASTER. This happens after f-host reboots if `nfs_reserved_port_only` is not set to `NO` in rc.conf. The nfsd rc script (`/etc/rc.d/nfsd`) explicitly sets the sysctl based on this variable, overriding `/etc/sysctl.conf`. Fix: `doas sysrc nfs_reserved_port_only=NO` on both f0 and f1.

### stunnel appears not running but port 2323 is bound

`carpcontrol.sh` starts stunnel on CARP MASTER transition, but doesn't write a PID file. So `service stunnel status` reports "not running" even though stunnel is actually serving connections. Check with `doas sockstat -l | grep 2323`. If there's a stale stunnel process, kill it and restart: `doas kill <pid> && doas service stunnel start`.

### Pods stuck in ContainerCreating/Unknown after NFS recovery

After NFS is restored on the server side, the `nfs-mount-monitor` systemd timer on each r-node will auto-remount within ~10 seconds and force-delete stuck pods. If immediate recovery is needed: `mount /data/nfs/k3svolumes` on each r-node, then delete the stuck pods manually.

**Note:** The monitor catches three failure modes: missing mountpoint, stat hang (reads unresponsive), and **silent write hang** (reads OK but writes block — the hardest case, e.g. stunnel-wrapped NFSv4 after a CARP failover). Watch the consecutive-failure counter via Prometheus (`nfs_mount_monitor_consecutive_failures`) — warning fires at ≥3, critical at ≥5. At 5 consecutive failures the node cordons itself and reboots.

### ZFS pool SUSPENDED recovery

**Symptoms**: `doas zpool status zdata` shows `state: SUSPENDED`. All IO to the pool is
halted — ZFS suspends itself to prevent corruption when IO errors exceed the threshold.
Commands like `zpool clear`, `zpool scrub`, `zpool offline`, and even `ls /data/nfs/` hang
indefinitely because they wait for kernel IO that will never complete.

**Known cause (2026-05-15)**: Samsung 870 EVO 1TB on f0 (ada1) hit 107 read errors and
105M+ write errors during normal operation — likely thermal throttling or a momentary
SATA connection loss. A previous resilver on 2026-01-27 suggests the drive has been
marginal for months.

**Recovery — hard power cycle only**:
- Do NOT attempt `doas shutdown -r now` — if ZFS is suspended, the graceful shutdown hangs
  at ZFS pool export and may stay stuck for 30–60+ minutes.
- Do NOT attempt `doas zpool clear zdata` — it hangs because ada1 is unresponsive.
- Do NOT attempt `doas ifconfig re0 vhid 1 state backup` or `doas carp backup` to fail
  over to f1 first — these ifconfig ioctls can also be blocked when the kernel has too
  many stuck IO threads. They may return exit=1 silently.
- **Hard power cycle** (pull power or hold the power button) resolves the issue in ~9 s
  (Rocky Linux VMs come up automatically, ZFS pool imports cleanly on next boot).

**Post-recovery**:
```sh
# 1. Verify pool health
doas zpool status zdata          # should show ONLINE, 0 errors

# 2. Check SMART for drive health
doas smartctl -a /dev/ada1 | grep -iE '(temperature|reallocated|pending|uncorrectable|error)'

# 3. Start a scrub to verify data integrity
doas zpool scrub zdata
doas zpool status zdata          # monitor; "scrub repaired 0 in ..." means data intact

# 4. Verify NFS is serving (stunnel listening on CARP VIP)
doas sockstat -l | grep 2323
```

**After cluster recovery**:
- Check for cordoned nodes: `kubectl get nodes` — if r0/r1/r2 show `SchedulingDisabled`,
  uncordon them (see nfs-mount-monitor escalation section above).
- Reset fail counters on all r-nodes: `echo 0 > /var/lib/nfs-mount-monitor/fail-count`

**Temperature monitoring** to detect thermal issues before they cause pool suspension:
```sh
# FreeBSD: load coretemp for CPU package temperature
doas kldload coretemp
sysctl -a | grep temperature                      # hw.acpi.thermal.*: and dev.cpu.*:
# Persist across reboots
echo 'coretemp_load="YES"' | doas tee -a /boot/loader.conf

# SSD temperature (install smartmontools if absent)
doas pkg install -y smartmontools
doas smartctl -a /dev/ada1 | grep -i temperature  # "194 Temperature_Celsius"
```

## Thermal Troubleshooting

### Symptoms of thermal throttling on f-hosts

- SSD I/O slowness (writes dropping from MB/s to KB/s)
- ZFS txg sync times jumping from <100ms to 5-37 seconds
- `zpool trim` stuck at 0% or paused indefinitely
- rsync / zrepl jobs going into D-state (waiting on ZFS I/O)
- High system CPU (80%+) from encryption overhead (ZFS native AES-256-GCM)

### How to check temperatures

- **coretemp (real per-core die temps)**: `kldload coretemp; sysctl dev.cpu | grep temperature`
  - Should now auto-load via `/boot/loader.conf` (`coretemp_load="YES"`)
- **hw.acpi.thermal.tz0**: Often a constant lie (e.g. always 27.9°C) — do NOT rely on it
- **SSD temperature**: `smartctl -a /dev/adaN` (requires smartmontools; may not be installed)
- **Disk I/O performance**: `gstat -bp -I 1s -d` (FreeBSD gstat, not Linux iostat)
- **ZFS txg sync times**: `zpool events | grep -i sync` or check via `zpool status -v`

### Beelink S12 Pro specifics

- Small enclosure with passive/minimal cooling — heat accumulates fast under sustained load
- N100 CPU: normal idle ~40-55°C, warn >70°C idle, critical >85°C under load
- NVMe sits close to CPU — both heat each other in the small chassis
- Enclosure gets hot to the touch before temps fully register in software

### Cascade failure pattern (2026-05-16 f0 incident)

The following cascade was observed:

1. Hot enclosure (NVMe physically very hot) → SSD thermal throttling
2. Concurrent rsync + 1-min zrepl snapshots + paused scrub → high I/O demand
3. autotrim=off (never trimmed) → SSD write amplification → further slowdown
4. ZFS native AES-256-GCM encryption → high CPU per I/O → txg sync times 5-37s
5. TRIM stuck at 0% for hours (couldn't make progress under continuous I/O load)
6. rsync went into D-state waiting on ZFS → appeared "hung"

**Root causes**: (a) autotrim=off (SSD never trimmed); (b) hot enclosure + thermal throttling;
(c) zrepl snapshot interval too aggressive (1m).

**Resolution**: Reseat/inspect drive + enclosure. After hardware fix, autotrim=on enabled,
manual TRIM ran to completion at ~2.4 GB/s. See "SSD TRIM Configuration" section.

### Remediation steps

1. SSH in and check temps: `kldload coretemp && sysctl dev.cpu | grep temperature`
2. If >80°C: stop heavy I/O workloads immediately (`service zrepl stop`, cancel scrubs)
3. Physical: shut down, reseat NVMe, clean dust from vents, improve airflow
4. After hardware fix: enable autotrim (`zpool set autotrim=on <pool>`) and run `zpool trim <pool>`
5. Monitor trim progress: `zpool status | grep trim`
6. Persist coretemp: ensure `/boot/loader.conf` has `coretemp_load="YES"` (see task 95)

### Checklist for NFS outage on CARP MASTER (f0 or f1)

```sh
# 1. Check which host is CARP MASTER
ssh paul@f0 'ifconfig re0 | grep carp'
ssh paul@f1 'ifconfig re0 | grep carp'

# 2. On the MASTER, verify:
doas sysctl vfs.nfsd.nfs_privport          # must be 0
doas service nfsd status                   # must be running
doas sockstat -l | grep 2323              # stunnel must be listening
ls /data/nfs/nfs.DO_NOT_REMOVE            # ZFS dataset must be mounted

# 3. Fix if needed:
doas sysrc nfs_reserved_port_only=NO      # persist the fix
doas sysctl vfs.nfsd.nfs_privport=0       # apply immediately
doas service nfsd restart
# For stunnel, kill stale process if needed, then:
doas service stunnel start
```

## NFS Auto-Repair: nfs-mount-monitor

A systemd timer+service pair on r0/r1/r2 checks the NFS mount every 10 seconds and automatically repairs it if stale or missing.

### Repo location

```
f3s/r-nodes/nfs-mount-monitor/
  check-nfs-mount.sh          # repair script → /usr/local/bin/
  nfs-mount-monitor.service   # one-shot service → /etc/systemd/system/
  nfs-mount-monitor.timer     # 10-second timer  → /etc/systemd/system/
f3s/r-nodes/Rexfile           # Rex deploy task: nfs_mount_monitor
```

### Deploy

```sh
# From repo root — pushes to all three r-nodes and reloads systemd if anything changed
rex -f f3s/r-nodes/Rexfile nfs_mount_monitor
```

### What it does

Three probes run in sequence on every 10-second tick:

1. **mountpoint probe** — detects completely missing mounts.
2. **stat probe** (`timeout 2s stat`) — detects read hangs / stale cache misses.
3. **write probe** (`timeout 5s sh -c "echo $$ > .healthcheck.<host> && rm -f ..."`) —
   detects the "reads OK, writes hang" failure mode. Stunnel-wrapped NFSv4 can enter
   a state where `stat` returns from cache but all writes block indefinitely; only this
   probe catches it.

If any probe fails, `fix_mount` runs:

1. `mount -o remount -f` (cheapest, no disruption if mount is merely stale)
2. Kill D-state processes pinning the mount (`kill_pinning_processes` — SIGKILLs
   processes whose `wchan` starts with `nfs_` and whose cwd/fds point into the mountpoint)
3. `umount -f` (force unmount)
4. `umount -l` (lazy detach VFS node if `-f` failed)
5. `systemctl restart stunnel` + 2s sleep (refresh the TLS transport)
6. `mount -t nfs4 -o port=2323,soft,timeo=50,retrans=3` (explicit soft NFS mount — NOT
   `mount $MOUNT_POINT` which reads fstab's `hard` flag and enters uninterruptible D-state
   if the server is unreachable; SIGKILL cannot wake a D-state process on Linux;
   `soft,timeo=50,retrans=3` returns ETIMEDOUT after ~15 s so the fail counter can
   increment and eventually trigger the reboot escalation)

A hard **60-second deadline** prevents `fix_mount` from outlasting its own timer interval.

On successful repair, force-deletes pods on this node stuck in
Unknown / Pending / ContainerCreating so the kubelet can reschedule them.

**Consecutive-failure escalation**: each `fix_mount` failure increments a counter
persisted to `/var/lib/nfs-mount-monitor/fail-count`. At `NFS_FAIL_THRESHOLD=5`
consecutive failures (~50 s), the node cordons itself (`kubectl cordon`) and issues
`systemctl reboot`. The cordon is stored in etcd and **persists across reboots** —
after the underlying NFS issue is resolved, manually uncordon each affected node:
```sh
kubectl uncordon r0.lan.buetow.org
kubectl uncordon r1.lan.buetow.org
kubectl uncordon r2.lan.buetow.org
```

The counter is also exported to `/var/lib/node_exporter/textfile_collector/nfs_mount_monitor.prom`
so Prometheus can alert on `nfs_mount_monitor_consecutive_failures` without parsing
journal logs (warning ≥3, critical ≥5 — see
`f3s/prometheus/manifests/nfs-mount-monitor-alerts.yaml`).

Uses a lock file (`/var/run/nfs-mount-check.lock`) to prevent overlapping runs
since the timer fires faster than the script's worst-case runtime. If the lock is
older than **90 seconds** it was left by a run that was SIGKILLed before its EXIT
trap could clean up (systemd kills with SIGKILL after its own timeout, bypassing
`trap "rm -f $LOCK_FILE" EXIT`); the stale lock is removed and the run continues,
preventing all health checks from being silently skipped forever.

### Timer configuration

| Parameter | Value | Reason |
|-----------|-------|--------|
| `OnBootSec` | 30s | Let network and NFS client start before first check |
| `OnUnitActiveSec` | 10s | Check interval; each run is bounded by a 60-second deadline |
| `AccuracySec` | 1s | Prevent systemd batching from delaying the 10 s interval |

### Managing the monitor during an extended NFS outage

During a prolonged NFS outage (e.g. while the storage host is being power-cycled or
repaired), stop the timer on affected r-nodes to prevent the escalation counter from
reaching the auto-reboot threshold prematurely:

```sh
# On each affected r-node (as root)
systemctl stop nfs-mount-monitor.timer
echo 0 > /var/lib/nfs-mount-monitor/fail-count   # reset counter

# After NFS is restored, restart and verify
systemctl start nfs-mount-monitor.timer
journalctl -u nfs-mount-monitor -f
```

Also reset the counter to 0 after uncordoning nodes (see escalation section above),
because the old counter value would lower the effective threshold for the next outage.

### Status and logs

```sh
systemctl status nfs-mount-monitor.timer
journalctl -u nfs-mount-monitor -f
```

## AWS S3 Glacier Deep Archive Backups

Encrypted incremental ZFS snapshots from `zdata` pool backed up daily to **AWS S3 Glacier Deep Archive** via cron. Scripts adapted from FreeBSD Home NAS setup. Also performs periodic zpool scrubbing.

## Local-Path Storage for SQLite Workloads

Some k3s workloads use `local-path` (k3s default storageClass) instead of NFS for
their data volumes. This is appropriate when:

- The application uses SQLite: NFS file-lock semantics cause `fcntl()` races on
  pod restarts, and `Recreate` strategy only reduces (not eliminates) the risk.
- Cache-heavy workloads: NFS over stunnel adds TLS round-trip latency to every
  cache read. Navidrome's image/background cache init took ~19s over NFS; it
  takes ~25ms from local disk.

**Trade-off**: a local-path PV lives on one specific node. If that node is down,
the pod reschedules elsewhere but finds no data volume — it starts with an empty DB,
losing play history, scrobble queue, etc. For a home server this is acceptable.
The deployment must pin the pod to the same node via `nodeSelector` so the local
PV is always reachable.

### Workloads using local-path

| App | Node | Path on node |
|-----|------|--------------|
| navidrome `/data` (DB + cache) | r1 | `/var/lib/rancher/k3s/storage/pvc-*_services_navidrome-data-pvc` |

### Migrating NFS hostPath → local-path

1. Disable ArgoCD auto-sync: `kubectl patch application <app> -n cicd --type=json -p='[{"op":"replace","path":"/spec/syncPolicy","value":{}}]'`
2. Scale deployment to 0: `kubectl scale deployment <app> -n services --replicas=0`
3. Delete old PVC and static PV.
4. Create new PVC with `storageClassName: local-path`.
5. Create a migration pod pinned to the target node that mounts both the NFS hostPath
   (source) and the new PVC (target); copy data with `cp -av /src/. /dst/`.
6. Delete migration pod, apply updated deployment (with `nodeSelector`), scale back up.
7. Re-enable ArgoCD auto-sync and push manifests to git; push to in-cluster git-server
   (`git push r0 master`) so ArgoCD picks up the new storageClass spec.

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
