# Backups and Local-Path Storage

## AWS S3 Glacier Deep Archive Backups

The offsite backup is the **`zusb` quarterly workflow**. The removable `zusb`
pool (see [USB Key Mounting](usb-keys.md) → "Removable backup pool (`zusb`)")
is plugged into an f-host roughly once per quarter, and
`/opt/snonux/bin/backup/backup` — which travels on the pool under
`zusb/data/opt` — exports dated `zfs send` snapshots of the `zusb/data/*`
datasets into encrypted archive chunks on `zusb/backup/<host>/<year>/`
(`gzip` → `openssl enc -aes-256-cbc -pbkdf2 -pass file:/opt/snonux/secrets/<host>.backup.phrase` → `split`), then `aws s3 sync ... --storage-class DEEP_ARCHIVE`
uploads them to `s3://org-buetow-backup/<host>/`. The script's `HOSTNAME=t450`
override keeps the S3 key prefix stable across the t450→f-hosts migration.

The backup runs `aws` as root on whichever f-host currently hosts `zusb`, so the
AWS CLI must be installed there and credentials wired in.

**Reality note (2026-07-20):** there is **no daily `zdata`→S3 cron** on any
f-host — the old "zdata daily to S3 via cron" setup is no longer present
(verified: no aws/s3/backup cron entries in root's crontab on f0/f1/f2/f3, and
no `/root/.aws` pre-existed on any of them). The `zusb` quarterly workflow
above is the only live S3 offsite backup. It backs up the `zusb/data/*`
personal datasets, **not** the f-host `zdata` pool; `zdata` redundancy comes
from zrepl replication (f0→f1), not S3. If a daily `zdata`→S3 cron is ever
reinstated, it would need its own always-available aws credentials (not the
zusb-pool symlink below), since it must run without `zusb` imported.

### AWS CLI setup on a FreeBSD host

Install the `awscli` package. The Python flavor depends on the FreeBSD version:

```sh
# FreeBSD 14.x (e.g. t450)
#   py39-awscli-1.29.81
# FreeBSD 15.x (e.g. f1, f-hosts)
#   py312-awscli-1.42.44
sudo pkg install -y py312-awscli   # adjust py3XX to what pkg search -q awscli shows
```

Wire `/root/.aws` (the backup script runs `aws` as root). The **credentials ride on the `zusb` pool** at `/opt/snonux/secrets/aws.credentials` (INI: `[default]` + `aws_access_key_id` + `aws_secret_access_key`), so on any host that has `zusb` imported (i.e. `/opt` mounted) you only need the config file and a symlink — the secret is not duplicated on host disks and is not in git:

```sh
sudo mkdir -p /root/.aws && sudo chmod 700 /root/.aws
printf '[default]\nregion = eu-central-1\n' | sudo tee /root/.aws/config >/dev/null
sudo chmod 600 /root/.aws/config
sudo ln -sf /opt/snonux/secrets/aws.credentials /root/.aws/credentials
```

Because the credentials are a symlink into `/opt` (`zusb/data/opt`), `aws` only
resolves them while `zusb` is imported on that host. That is exactly right for
the quarterly workflow (load `zusb` → run backup → export `zusb`); on the other
f-hosts the symlink is deliberately **dangling until `zusb` is replugged there**,
at which point `/opt` mounts and it resolves. No secret material lives on host
disks or in git.

Verify (read-only):

```sh
aws --version
aws sts get-caller-identity        # expect Arn arn:aws:iam::634617747016:user/org-buetow-backup-user
aws s3 ls s3://org-buetow-backup/   # expect the per-host prefixes (e.g. t450/)
```

Installed 2026-07-20 on **all f-hosts** (f0/f1/f2/f3, `py312-awscli-1.42.44`),
matching the t450 setup (`py39-awscli-1.29.81`, same `/root/.aws/config` region
and the same credentials symlink). Verified working on f1 (where `zusb` is
hosted) via `aws sts get-caller-identity` → `org-buetow-backup-user`; on
f0/f2/f3 the symlink is dangling until `zusb` is imported there. (f0 previously
had a stale, never-configured `py311-awscli` package, now replaced by `py312`.)

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
