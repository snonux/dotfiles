# Quarterly Backups

Runbook for the ~quarterly backup session. The human checklist lives in
`~/Notes/Lists/Backup.md`; this file holds the agent-facing procedures for each
step as they are exercised. Do not run steps unless asked.

**Agent execution:** start every long-running command in the **background**
(shell `block_until_ms: 0`, log via `tee`), then **wait until it finishes**
(`AwaitShell` / poll the terminal until `exit_code` appears) before reporting
the result or moving on. Do not abandon a background job mid-run unless the
user stops it. Short checks (zrepl canary, `zfs list`, `ls`) may stay
foreground.

Order matters: sync git from **earth** first, then confirm f0→f1 zrepl before
mounting `zusb` on **f1** (later steps treat f1's NFS sink and `/srv/data/enc`
as backup sources).

Related: [zrepl Replication](zrepl.md) (canary / troubleshooting),
[USB Key Mounting](usb-keys.md) (`zusb` load/unload),
[Backups & Local-Path](backups.md) (S3 / AWS CLI on the `zusb` host).

## Checklist map

| # | Step | Status in this runbook |
|---|------|------------------------|
| 1 | gitsyncer on earth | Documented below |
| 2 | Check zrepl f0→f1 in sync | Documented below |
| 3 | Mount `zusb` on f1 + confirm enc keys | Documented below |
| — | Remaining checklist items | Not yet documented here — follow `Backup.md` |

## 1. gitsyncer (earth)

On the **earth** laptop, bidirectional-sync all configured git remotes and
auto-create any missing releases. This often takes many minutes (tens of
repos) — **background it and wait for completion** (see top of this file).

Good practice: wipe the workdir first so clones are fresh (avoids stale
partial state). Default workdir is `~/git/gitsyncer-workdir`.

```sh
# on earth — run in background; tee log; await exit before next step
rm -rf ~/git/gitsyncer-workdir
gitsyncer sync bidirectional --force --backup --auto-create-releases \
  2>&1 | tee /tmp/gitsyncer-quarterly-$(date +%Y%m%d-%H%M%S).log
```

- `--force` — do not skip repos based on the normal sync-interval checks
- `--backup` — include any backup locations from config
- `--auto-create-releases` — create missing releases without prompting

### Pass criteria

1. Background job exits 0
2. No repos left in a failed/error state in the summary (re-run or fix
   auth/remote issues for any that failed)

## 2. Verify f0 → f1 zrepl is in sync

Job: `f0_to_f1_nfsdata` pushes `zdata/enc/nfsdata` to f1 every minute.
Replica path on f1: `zdata/sink/f0/zdata/enc/nfsdata` (mounted read-only at
`/data/nfs`).

f0's root cron (every 10 min) writes a unix epoch into
`/data/nfs/nfs.LIVE_CHECK` when the sentinel `nfs.DO_NOT_REMOVE` exists. That
file (and its mtime) appears on f1 after the next replication.

### On f1 — canary lag (primary check)

Expect age **< ~660s** (10 min cron + ~1 min zrepl). Larger → stalled; see
[zrepl Troubleshooting](zrepl.md#troubleshooting).

```sh
# on f1
echo $(( $(date +%s) - $(cat /data/nfs/nfs.LIVE_CHECK) ))
stat -f '%Sm' /data/nfs/nfs.LIVE_CHECK
```

### Matching latest snapshots

Latest `@zrepl_*` on f0's source and f1's sink should be the same name and
within about a minute of each other:

```sh
# on f0
zfs list -t snap -o name,creation -s creation zdata/enc/nfsdata | tail -5

# on f1
zfs list -t snap -o name,creation -s creation zdata/sink/f0/zdata/enc/nfsdata | tail -5
```

### Push job health (optional)

```sh
# on f0 — interactive TTY: doas zrepl status
# non-TTY / scripted:
doas zrepl status --mode raw | python3 -c '
import json,sys
j=json.load(sys.stdin)["Jobs"]["f0_to_f1_nfsdata"]["push"]["Replication"]
a=j["Attempts"][-1]
print("attempt", a["State"], "start", a["StartAt"], "finish", a["FinishAt"])
for fs in a["Filesystems"]:
    print(fs["Info"]["Name"], fs["State"], "err", fs.get("StepError") or fs.get("PlanError"))
'
```

Expect the latest attempt and `zdata/enc/nfsdata` both `done`, no step/plan
errors.

### Pass criteria

1. f1 canary age < ~660s
2. Latest `@zrepl_*` snap names match on f0 source and f1 sink
3. (If checked) push attempt state `done` with no errors

Verified healthy 2026-10-17 (canary ~60s, snaps matched through
`@zrepl_20261017_185001_000`).

## 3. Mount `zusb` on f1 and confirm encryption keys

Do this only after f0→f1 zrepl is in sync (step 2). The removable pool is
usually plugged into **f1** for the quarterly session. Full load/unload
behaviour (USB power, SCSI start/stop, key path) is in
[USB Key Mounting](usb-keys.md) → "Removable backup pool (`zusb`)".

### Load the pool

```sh
# on f1
doas /usr/local/bin/zusb-load
```

Expect `zusb loaded:` followed by a table of datasets. `f3s-mount-keys` may
print `/keys is already mounted`; that is fine.

### Pool imported and datasets mounted

```sh
# on f1
doas zpool status zusb
zfs list -o name,keystatus,mounted,mountpoint -r zusb
```

Expect:

| Dataset | Mountpoint | Notes |
|---------|------------|--------|
| `zusb` | `/zusb/zusb` | pool root |
| `zusb/backup` | `/backup` | offsite archive staging |
| `zusb/data` | `/srv/data` | |
| `zusb/data/enc` (+ children) | `/srv/data/enc/...` | encryption root + kids |
| `zusb/data/opt` | `/opt` | backup scripts / AWS creds symlink target |

All listed datasets `MOUNTED=yes`. Every `zusb/data/enc*` row
`KEYSTATUS=available` (encryption root `zusb/data/enc`). No child under
`zusb/data/enc` should be `mounted=no`.

`zpool status` may still report an old permanent error on a single music
snapshot file (Rihanna `02 James Joint.flac` on `@20260722`–`@20260807` as of
2026-10-17) while vdevs stay ONLINE with 0 READ/WRITE/CKSUM — note it, do not
treat it as a failed load.

### Confirm `/srv/data/enc/*` is readable (keys really loaded)

`keystatus=available` alone is not enough for peace of mind: readdir and read a
byte as root. Permission-denied as an unprivileged user on `secrets/`
(`drwx------`) or root-owned cache files is **not** a key failure.

```sh
# on f1 — any unavailable key?
zfs list -H -o name,keystatus,mounted -r zusb/data/enc | awk '$1 !~ /@/ && $2 != "available" {print}'
# (empty = all keys available)

# every enc child + common non-dataset dirs under enc
for d in backups books documents games git mail music musicvideos notes \
         pictures secrets stuff videos xman yoga cloud; do
  doas ls "/srv/data/enc/$d" >/dev/null && echo "OK $d" || echo "FAIL $d"
done

# sample file read under a non-secrets dataset
doas dd if="$(doas find /srv/data/enc/documents -type f | head -1)" \
  of=/dev/null bs=1 count=1 status=none && echo 'sample read OK'
```

### Pass criteria

1. `zusb-load` exits 0 and prints the dataset table
2. `zpool status zusb` → ONLINE (imported)
3. All `zusb/data/enc` datasets `keystatus=available`, `mounted=yes`
4. As root, every `/srv/data/enc/<child>` readdir succeeds; at least one file
   under a non-empty dataset reads successfully

Done 2026-10-17 on f1: load OK; all 15 enc children + non-dataset dirs under
`enc` readable as root; sample reads OK.
