# Backups and Local-Path Storage

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
