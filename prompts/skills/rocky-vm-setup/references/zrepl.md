# ZFS Snapshot / Replication

The rocky VM dataset `zroot/bhyve/rocky` is managed by **zrepl** on the FreeBSD host f3. It is **not** included in local `zfs-periodic` snapshots.

| Property | Value |
|------------|-------|
| Snapshots | Every 10 minutes via zrepl (`zrepl_` prefix) |
| Replication | f3 → f2 (`zroot/sink/f3/zroot/bhyve/rocky`) |
| Retention | 10 immediate + 24 hourly + 14 daily |
| Local snap job | `zroot/bhyve/rocky` excluded from `local_zfs_snapshots` |

See [`f3s` skill zrepl.md](../../f3s-storage/references/zrepl.md) for full config.
