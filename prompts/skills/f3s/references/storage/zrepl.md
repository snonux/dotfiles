# zrepl: Continuous ZFS Replication

Continuous ZFS replication for the encrypted NFS dataset (f0 → f1) and the
standalone FreeBSD and Rocky VMs (f3 → f2). Original plan was HAST, replaced by
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
      "zroot/bhyve/homelabfs-lab<": true # parent + all test VM datasets
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

## f2 configuration (sink for f3's VM backups)

The sink lives in `zdata/sink` on f2's second SSD (928 GiB pool). It moved
from `zroot/sink` on 2026-10-17 after Rocky backup history filled the 472 GiB
OS pool and r2 stopped reporting to Kubernetes. Keep VM backups off `zroot`,
which also holds f2's OS and the active r2 virtual disk:

```sh
doas zfs create -o mountpoint=none zdata/sink
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
    root_fs: "zdata/sink"
```

Replicated paths:

- `zroot/bhyve/freebsd` → `zdata/sink/f3/zroot/bhyve/freebsd`
- `zroot/bhyve/rocky` → `zdata/sink/f3/zroot/bhyve/rocky`
- `zroot/bhyve/homelabfs-lab` and all descendants → `zdata/sink/f3/zroot/bhyve/homelabfs-lab` (added 2026-10-25)

Both VM backups remain encrypted raw receives, with `mountpoint=none` and
`keylocation=file:///keys/f3.lan.buetow.org:bhyve.key`. Both belong in
f2's `zfskeys_datasets` (see [USB keys](usb-keys.md)). Inventory, the sink
root, and snapshot exclusions are managed in `gonf/cluster/freebsd_storage.go`.
The f3 push job and its WireGuard endpoint stay the same when moving the sink.

Important: do not let `zfs-periodic` snapshot zrepl-managed sender or receiver
datasets. Snapshot creation should be owned by zrepl. On f2,
`/etc/periodic.conf` disables `zfs-periodic` snapshot creation:

```sh
daily_zfs_snapshot_enable="NO"
weekly_zfs_snapshot_enable="NO"
monthly_zfs_snapshot_enable="NO"
```

The local zrepl `snap` job on f3 excludes the two development VM datasets and the HomelabFS lab subtree so they are only snapshotted by the push job:

```yaml
  - name: local_zfs_snapshots
    type: snap
    filesystems:
      "zroot<": true
      "zroot/bhyve/freebsd": false
      "zroot/bhyve/rocky": false
      "zroot/bhyve/homelabfs-lab<": false
    ...
```

The local zrepl `snap` job on f2 includes `zdata<` and explicitly excludes
`zdata/sink<`; the push job owns backup snapshots and their pruning.

After a sink migration, compare completed snapshot GUIDs before removing the
old copy, then wake `f3_to_f2_freebsd` on f3 and confirm both filesystems
complete incremental replication. A raw send (`zfs send -w`) preserves the
encryption lineage required for later raw incrementals. After reboot, check
both backup keys are available, r2 is Ready, and a fresh replication completes.
Validated on 2026-10-17: f2 imported both pools, loaded both backup keys,
autostarted r2, and accepted a Rocky incremental after boot; sender and
receiver pruning both completed successfully.

The 2026-10-17 migration retained the latest completed Rocky backup and the
FreeBSD backup history; older Rocky receiver snapshots were removed with
permission to reclaim space. f3's snapshot retention policy remains
`last_n: 10` plus `24x1h | 14x1d` on sender and receiver. Snapshot counts do
not cap bytes: a VM image with heavy write activity can retain hundreds of
GiB even when its current image is much smaller. Check `usedbysnapshots`,
`available`, and `zrepl status` on both hosts when capacity is tight.

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

The standby replica is read-only by design, including while f1 is CARP MASTER.
Never set the receiver `readonly=off`, and never roll it back automatically.
If zrepl reports that the destination was modified, leave it untouched and
inspect changes from the latest received snapshot with `zfs diff` before
choosing a manual rollback or full re-seed.

## Troubleshooting

```sh
# Signal manual replication
doas zrepl signal wakeup f0_to_f1_nfsdata

# Before destructive recovery, identify and inspect receiver-side divergence
SINK=zdata/sink/f0/zdata/enc/nfsdata
LAST=$(zfs list -H -t snapshot -o name -s creation -r "$SINK" | tail -1)
zfs get "written@${LAST##*@}" "$SINK"
zfs diff -FH "$LAST" "$SINK"

# Fix "no common snapshot" only after confirming f0 is healthy and reviewing
# the diff above — destroy the receiver and let zrepl perform a full send
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

## HomelabFS test infrastructure copy

Added on 2026-10-25 to the existing ten-minute f3 push job: the complete
`zroot/bhyve/homelabfs-lab<` subtree, including hfs-test0, hfs-test1 and
hfs-test2. The parent contains the preparation manifest/public host keys;
each guest dataset contains its configuration and OS/ZFS data disk pair.
The copy is on f2's `zdata` pool, not its OS/active-r2 pool. The lab is
excluded from local snapshot creation on f3; prior local snapshots are
not deleted by this change. Retention is the same as Rocky.

Do not register received datasets as runnable VMs. Recovery requires fencing
the old guests, making writable recovery copies, reconstructing the `hfslab`
datastore and isolated bridge (172.31.253.1/24), and checking host RAM. f2
already runs r2: storing backups does not authorize stopping r2 or booting
three more guests. See `~/git/homelabfs/docs/Lab-replication.md` for recovery
steps and validation evidence. Running-VM snapshots are not guest-quiesced;
this is a periodic recovery copy, not automatic failover.

The lab parent and each of the three received guest datasets are separate
encryption roots. All four are configured with
`keylocation=file:///keys/f3.lan.buetow.org:bhyve.key` and listed in f2's
`zfskeys_datasets`. The recursive replication filter includes new descendants
automatically; register newly received encryption roots in the managed key
inventory before relying on automatic key loading for them.

Validation: first full lab copy completed at 11:53:21 EET on 2026-10-25;
a one-off `zrepl_verify_20261025_095352` snapshot completed incrementally
at 11:53:54. All eight GUIDs (two snapshots × four lab datasets) matched.
`zfs load-key -n` verified the existing f3 key against each received root.
Received datasets stayed unmounted; Rocky remained running and lab VMs
stayed stopped. No restore boot was performed.
