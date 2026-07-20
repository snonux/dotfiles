# zrepl: Continuous ZFS Replication

Continuous ZFS replication for the encrypted NFS dataset (f0 → f1) and the
standalone FreeBSD dev VM (f3 → f2). Original plan was HAST, replaced by
zrepl (`zfs send/recv`) — more reliable and avoids the HAST-induced ZFS
corruption that hit us during failover testing.

Install on the participating hosts:

```sh
doas pkg install -y zrepl
```

## f0 configuration (`/usr/local/etc/zrepl/zrepl.yml`)

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

## f3 configuration (push: VMs → f2)

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
      "zroot/bhyve/freebsd": true   # development FreeBSD VM
      "zroot/bhyve/rocky": true     # plain Rocky Linux VM
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

## f2 configuration (sink for f3's freebsd VM)

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

The local zrepl `snap` job on f3 also excludes both VM datasets so they are only snapshotted by the push job:

```yaml
  - name: local_zfs_snapshots
    type: snap
    filesystems:
      "zroot<": true
      "zroot/bhyve/freebsd": false
      "zroot/bhyve/rocky": false
    ...
```

The local zrepl `snap` job on f2 also explicitly excludes `zroot/sink<`.

## f1 configuration (sink)

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

## Enable and start

```sh
doas sysrc zrepl_enable=YES
doas service zrepl start
doas zrepl status   # monitor replication
```

Replicated paths: `zdata/enc/nfsdata` → `zdata/sink/f0/zdata/enc/nfsdata`

## Mount replica on f1 (read-only standby)

```sh
doas zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key \
  zdata/sink/f0/zdata/enc/nfsdata
doas mkdir -p /data/nfs
doas zfs set mountpoint=/data/nfs zdata/sink/f0/zdata/enc/nfsdata
doas zfs mount zdata/sink/f0/zdata/enc/nfsdata
doas zfs set readonly=on zdata/sink/f0/zdata/enc/nfsdata   # prevent replication breakage
```

## Replication liveness check

A small cron job on f0 writes a canary file into the replicated dataset so its
content and mtime on f1's read-only sink reveal how fresh the zrepl replication
is.

On **f0** (root crontab), every 10 minutes, gated on a sentinel file so the
canary only runs when the dataset is actually in use, the job touches the file
and writes the current unix epoch into it:

```
*/10 * * * * test -f /data/nfs/nfs.DO_NOT_REMOVE && /usr/bin/touch /data/nfs/nfs.LIVE_CHECK && /bin/date +\%s > /data/nfs/nfs.LIVE_CHECK
```

Note: the `\%` is required — cron treats an unescaped `%` as a newline/stdin
separator, so `date +%s` would silently break. In an interactive shell you'd
write `date +%s` (no backslash).

`/data/nfs` on f0 is `zdata/enc/nfsdata` — the dataset the `f0_to_f1_nfsdata`
job pushes to f1 every minute. zrepl snapshots + sends, so `nfs.LIVE_CHECK`
(its epoch content and mtime) appears on f1's read-only sink at
`/data/nfs/nfs.LIVE_CHECK` within roughly one replication interval.

On **f1**, read the replica to check freshness (the sink is read-only) — either
compare the epoch inside the file to f1's clock, or compare mtimes:

```sh
echo $(( $(date +%s) - $(cat /data/nfs/nfs.LIVE_CHECK) ))   # seconds since f0 last wrote (expect <~660)
stat -f '%Sm' /data/nfs/nfs.LIVE_CHECK                      # f0's last write time, as replicated
date '+%Sm'                                                  # compare to now
```

If the lag exceeds ~10–11 minutes (10-min cron interval + 1-min zrepl
replication), zrepl replication is stalled (see Troubleshooting). The
`/data/nfs/nfs.DO_NOT_REMOVE` sentinel also doubles as the canary guard.
Installed on f0 2026-07-20.

## Failover design: intentionally read-only replica

The standby replica is read-only by design. Manual failover (not automatic) to prevent split-brain. To fix broken replication after accidental writes: `doas zfs rollback <snapshot>`.

## Troubleshooting

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
