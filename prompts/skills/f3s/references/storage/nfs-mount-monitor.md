# NFS Auto-Repair: nfs-mount-monitor

A systemd timer+service pair on r0/r1/r2 checks the NFS mount every 10 seconds and automatically repairs it if stale or missing.

## Repo location

```
f3s/r-nodes/nfs-mount-monitor/
  check-nfs-mount.sh          # repair script → /usr/local/bin/
  nfs-mount-monitor.service   # one-shot service → /etc/systemd/system/
  nfs-mount-monitor.timer     # 10-second timer  → /etc/systemd/system/
f3s/r-nodes/Rexfile           # Rex deploy task: nfs_mount_monitor
```

## Deploy

```sh
# From repo root — pushes to all three r-nodes and reloads systemd if anything changed
rex -f f3s/r-nodes/Rexfile nfs_mount_monitor
```

## What it does

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

## Timer configuration

| Parameter | Value | Reason |
|-----------|-------|--------|
| `OnBootSec` | 30s | Let network and NFS client start before first check |
| `OnUnitActiveSec` | 10s | Check interval; each run is bounded by a 60-second deadline |
| `AccuracySec` | 1s | Prevent systemd batching from delaying the 10 s interval |

## Managing the monitor during an extended NFS outage

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

## Status and logs

```sh
systemctl status nfs-mount-monitor.timer
journalctl -u nfs-mount-monitor -f
```
