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

**Hourly status (required while waiting):** once `rsync-data-to-zusb`,
`backup start`, and/or the `zusb` scrub are in flight and the agent is not
blocked on a user OK, arm a **1h** local loop (`/loop` / monitored shell
sentinel) and post a short status each tick until those jobs finish (or the
user stops the loop). Do **not** hold a multi-hour SSH `AwaitShell` for the
whole backup — use `nohup` on f1 plus hourly check-ins.

Each hourly update should include: whether `backup` / `rsync-data-to-zusb` /
scrub are still running; latest meaningful `backup start` log lines (normalize
`\r`); scrub `%` and ETA; `rocky` state. When all three background pieces are
done, stop the loop and continue with **Verify background jobs… /
`zusb-unload`**.

```sh
# local agent loop (1h) — emit sentinel; agent reports status on each tick
while true; do
  sleep 3600
  echo 'AGENT_LOOP_TICK_f3s_quarterly_backup {"prompt":"Hourly f3s quarterly backup status: check backup start, rsync-data-to-zusb, zusb scrub, and rocky on f1; report briefly. Stop this loop when backup+scrub are done and proceed to unload if appropriate."}'
done
```

Order matters: on the **f1** backup host, stop the `rocky` bhyve VM first (frees
RAM/I/O), then sync git from **earth**, confirm f0→f1 zrepl, and mount `zusb`
on **f1** (later steps treat f1's NFS sink and `/srv/data/enc` as backup
sources). On f1, run **`rsync-data-to-zusb` to completion before `backup
start`** — never in parallel (snapshots must see the finished rsync tree; both
are heavy I/O). Scrub may overlap either. Start `rocky` again only after the
session’s final unload step.

Related: [zrepl Replication](zrepl.md) (canary / troubleshooting),
[USB Key Mounting](usb-keys.md) (`zusb` load/unload),
[Backups & Local-Path](backups.md) (S3 / AWS CLI on the `zusb` host).

## Checklist map

The **Checklist map** is the source of truth for step order and numbers.
Section headings must be `## N. …` matching this table 1…N in order.

**When adding, removing, or reordering a step:** **auto-enumerate** every
documented step so numbers stay contiguous — no gaps, no duplicates, no
leftover old numbers. In the same edit: (1) rewrite the Checklist map `#`
column as `1…N` with no skipped integers, (2) renumber every `## N.`
procedure heading to the same sequence, (3) fix any remaining numeric
"step N" mentions (prefer **step titles** over bare numbers), (4) update
the one-line blurb in [storage.md](../storage.md) if it lists steps.
Example: deleting former step 3 turns old 4→3 and 5→4; inserting after 2
shifts former 3…N up by one. Never leave `1,2,4` or two different
sections both numbered `3`.

| # | Step | Status in this runbook |
|---|------|------------------------|
| 1 | Stop `rocky` VM on f1 | Documented below |
| 2 | gitsyncer on earth | Documented below |
| 3 | Check zrepl f0→f1 in sync | Documented below |
| 4 | Mount `zusb` on f1 + confirm enc keys | Documented below |
| 5 | Start `zpool scrub zusb` on f1 | Documented below |
| 6 | Review k3svolumes **not** covered by `rsync-data-to-zusb` | Documented below |
| 7 | Sync `worktime` + `recovery` + `iq` git → f1 zusb | Documented below |
| 8 | Run `~/Syncthing/**/rsync-data-to-usb` on earth | Documented below |
| 9 | `rsync-data-to-zusb` (k3svolumes → zusb) on f1 | Documented below (finish before 10) |
| 10 | `backup start` on f1 (ZFS snap + S3) | Documented below (after 9 completes) |
| 11 | Verify bg jobs done, report log errors, `zusb-unload` | Documented below |
| 12 | Start `rocky` VM on f1 | Documented below |
| — | Remaining checklist items | Not yet documented here — follow `Backup.md` |

## 1. Stop `rocky` VM on f1

Free RAM and I/O on the **f1** backup host before scrub / rsync / `backup
start`. f1 uses **vm-bhyve** (`vm`), not OpenBSD `vmctl`.

```sh
# on f1
doas vm stop rocky
# wait until Stopped (ACPI can take ~30–60s)
doas vm list   # rocky … Stopped
```

### Pass criteria

1. `doas vm list` shows `rocky` as **Stopped**
2. Do not start it again until **Start `rocky` VM on f1** at the end of the
   session

Done 2026-10-18: stopped on f1 for this quarterly run.

## 2. gitsyncer (earth)

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

## 3. Verify f0 → f1 zrepl is in sync

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

## 4. Mount `zusb` on f1 and confirm encryption keys

Do this only after **Check zrepl f0→f1 in sync**. The removable pool is
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

## 5. Start `zpool scrub zusb` on f1

Right after **Mount `zusb` on f1 + confirm enc keys** (pool imported). Scrub
runs in the kernel in the background and survives SSH/laptop disconnect; it
may overlap **`rsync-data-to-zusb`** or **`backup start`**, but those two
steps themselves stay **sequential** (rsync first, then backup).

```sh
# on f1 — skip if already scrubbing
doas zpool status zusb | grep -qi 'scrub in progress' \
  || doas zpool scrub zusb
doas zpool status zusb   # expect: scrub in progress since …
```

Check later (also in `Backup.md` near the end of the session):

```sh
doas zpool status zusb
# done when scan line is like: scrub repaired … with N errors on <date>
```

### Pass criteria

1. `zpool scrub zusb` accepted (or scrub already in progress)
2. `zpool status zusb` shows `scrub in progress` (or a fresh completed scrub)

Started 2026-10-18 on f1: scrub in progress since 11:45 (pool still has the
known permanent music-snap data error from before).

## 6. Review k3svolumes coverage (`rsync-data-to-zusb`)

Right after **Start `zpool scrub zusb`**, **before** starting
`rsync-data-to-zusb`. Compare top-level entries under `/data/nfs/k3svolumes/`
to the sources in `/opt/snonux/bin/backup/rsync-data-to-zusb`.

**Agent presentation (required):** show the user **two clear Markdown
tables** in the chat (not a bare comma list). Do not invent new rsync lines
unless asked. Wait for an explicit OK / not-OK. Only then proceed to
**`rsync-data-to-zusb`**.

1. **Covered** — one row per script `rsync` line: volume, source path under
   `k3svolumes/`, destination under `/srv/data/enc/…`, and coverage note
   (`full` = whole volume root; `partial` = subdirectory only and/or
   excludes). Deduplicate identical lines (e.g. repeated `opodsync`).
2. **Not covered** — every top-level name under `k3svolumes/` that never
   appears as a script source, with `du -sh` size (or `(file)` /
   `(sentinel)` for non-dirs). Call out large gaps (e.g. `syncthing`).

```sh
# on f1
SCRIPT=/opt/snonux/bin/backup/rsync-data-to-zusb

# covered: source → dest (keep excludes visible in the partial notes)
grep -E '^\s*rsync ' "$SCRIPT"

# not covered (set difference on first path component)
comm -23 \
  <(ls -1 /data/nfs/k3svolumes/ | sort) \
  <(grep -E '^\s*rsync ' "$SCRIPT" \
      | sed 's/.*k3svolumes\///;s|/.*||;s| .*||' | sort -u)

# sizes for not-covered entries
comm -23 \
  <(ls -1 /data/nfs/k3svolumes/ | sort) \
  <(grep -E '^\s*rsync ' "$SCRIPT" \
      | sed 's/.*k3svolumes\///;s|/.*||;s| .*||' | sort -u) \
| while read -r name; do
  p=/data/nfs/k3svolumes/$name
  if [ -d "$p" ]; then du -sh "$p"
  elif [ -f "$p" ]; then echo "(file) $name"
  else echo "(other) $name"
  fi
done
```

Typical **partial** cases: `player` → `libraries/{audiobooks,musicvideos,yoga}`
only; `xplayer` → `libraries/` only; `navidrome` → `music/` only; `immich`
excludes `*external-library/videos/*`.

### Pass criteria

1. User sees both tables (covered with dest + partial notes; not-covered with
   sizes)
2. User says OK to proceed, or asks to extend `rsync-data-to-zusb` / run extra
   rsyncs **before** the next step starts the script

Snapshot as of 2026-10-19 — not covered (notable sizes): `syncthing` ~146G,
`prometheus` ~2.6G, `shuriken.sh` ~2.7G, `etcd-snapshots` ~105M, plus small
`apache`, `beets-art`, `bgtutor`, `freshrss`, `keybr`, `linkding`, `permtest`,
`pihole`, `ychat`, and non-volume noise (`k3svolumes.DO_NOT_REMOVE`,
`rsync-backup.sh.*`). Script lives on **zusb** at
`/opt/snonux/bin/backup/rsync-data-to-zusb` (edit in place on the host that
has `zusb` loaded).

## 7. Sync `worktime` + `recovery` + `iq` git → f1 zusb

Before the Syncthing / k3svolumes rsyncs, push the private **worktime**,
**recovery**, and **iq** repos from **earth** onto the mounted `zusb` git
tree on f1. Requires **Mount `zusb`…** (so `/srv/data/enc/git` is available).

**Destination rule:** every private bare mirror lives under

`/srv/data/enc/git/private/REPO.git`

— never `/srv/data/enc/git/REPO.git` (top-level). Remotes on earth must use
that `private/` path.

| Repo (earth) | Remote name | Destination on f1 |
|--------------|-------------|-------------------|
| `~/git/worktime` | `f1.lan` | `/srv/data/enc/git/private/worktime.git` |
| `~/git/recovery` | `zusb` | `/srv/data/enc/git/private/recovery.git` |
| `~/git/iq` | `f1.lan` | `/srv/data/enc/git/private/iq.git` |

```sh
# on earth — ensure bare repos exist (once) under private/
ssh f1.lan 'test -d /srv/data/enc/git/private/worktime.git \
  || git init --bare /srv/data/enc/git/private/worktime.git'
ssh f1.lan 'test -d /srv/data/enc/git/private/recovery.git \
  || git init --bare /srv/data/enc/git/private/recovery.git'
ssh f1.lan 'test -d /srv/data/enc/git/private/iq.git \
  || git init --bare /srv/data/enc/git/private/iq.git'

# confirm remotes point at private/ (fix if not; add if missing)
git -C ~/git/worktime remote get-url f1.lan
# expect: f1.lan:/srv/data/enc/git/private/worktime.git
git -C ~/git/recovery remote get-url zusb
# expect: paul@f1.lan:/srv/data/enc/git/private/recovery.git
git -C ~/git/iq remote get-url f1.lan
# expect: f1.lan:/srv/data/enc/git/private/iq.git
# one-time: git -C ~/git/iq remote add f1.lan f1.lan:/srv/data/enc/git/private/iq.git

# worktime — push all branches + tags
git -C ~/git/worktime push --all f1.lan
git -C ~/git/worktime push --tags f1.lan

# recovery — push all branches + tags
git -C ~/git/recovery push --all zusb
git -C ~/git/recovery push --tags zusb

# iq — push all branches + tags
git -C ~/git/iq push --all f1.lan
git -C ~/git/iq push --tags f1.lan
```

### Pass criteria

1. Remote URLs contain `/srv/data/enc/git/private/<repo>.git` (not top-level)
2. Each `push --all` / `push --tags` succeeds (or reports already up-to-date)
3. `git -C ~/git/worktime fetch f1.lan` and tip matches expectations
4. `git -C ~/git/recovery fetch zusb` and tip matches expectations
5. `git -C ~/git/iq fetch f1.lan` and tip matches expectations

Done 2026-10-18 (worktime): branches up-to-date; tag `audit/2026-08-09`
pushed; `f1.lan/master` at `a3dc7586`.

Done 2026-10-18 (recovery): remote URL fixed to `private/recovery.git`;
bare created there; old `/srv/data/enc/git/recovery.git` removed; `master`
pushed; `zusb/master` at `5777288` (matches local).

Done 2026-10-19 (iq): bare created at `private/iq.git`; remote `f1.lan`
added on earth; `main` pushed; `f1.lan/main` at `94b5d6e0` (matches local).

## 8. Run `~/Syncthing/**/rsync-data-to-usb` on earth

Before **`rsync-data-to-zusb` on f1**, from **earth**, find every
`rsync-data-to-usb` under `~/Syncthing` and run them **one after another**.
Each script starts with `cd "$(dirname "$0")" || exit 1` then rsyncs `.` —
so invoking `./Documents/rsync-data-to-usb` from `~/Syncthing` is safe (same
as the fish `f rsync | while read s; ./$s; end` pattern). Requires **Mount
`zusb`…** on f1 so destinations under `/srv/data/enc/…` exist. Log
stdout/stderr; report non-zero exits / rsync errors.

Name note: earth scripts are `rsync-data-to-usb`; f1's k3svolumes driver is
`rsync-data-to-zusb`.

```sh
# on earth — ~/Syncthing is a symlink; resolve it or find won't descend
ST=$(readlink -f ~/Syncthing)   # usually ~/syncthing
LOG=/tmp/syncthing-rsync-data-to-usb-$(date +%Y%m%d-%H%M%S).log
fail=0
while IFS= read -r -d '' script; do
  echo "===== $script =====" | tee -a "$LOG"
  "$script" >>"$LOG" 2>&1
  rc=$?
  echo "EXIT:$rc ($script)" | tee -a "$LOG"
  [ "$rc" -eq 0 ] || fail=1
done < <(find "$ST" -type f -name rsync-data-to-usb -print0 | sort -z)

grep -iE 'error|fail|IO error|rsync error|^EXIT:[1-9]' "$LOG" || true
[ "$fail" -eq 0 ]
```

Fish equivalent from `~/Syncthing`:

```fish
cd ~/Syncthing
f rsync | while read s; ./$s; end
```

Each script’s header comments point at the human checklist
`~/Notes/Lists/Backup.md` and name its f1 destination. Inventory (as of
2026-10-18):

| Script under `~/Syncthing/` | Destination on f1 |
|-----------------------------|-------------------|
| `Documents/rsync-data-to-usb` | `/srv/data/enc/documents/` |
| `earth/books/rsync-data-to-usb` | `/srv/data/enc/books/` |
| `GosDir/rsync-data-to-usb` | `/srv/data/enc/backups/GosDir/` |
| `Notes/rsync-data-to-usb` | `/srv/data/enc/notes/` |
| `Pixel7Pro/DCIM/rsync-data-to-usb` | `/srv/data/enc/pictures/paul/Diverse/` (excludes `Camera/`, no `--delete`) |

### Pass criteria

1. Every discovered script was run in sequence
2. Real rsync scripts exit 0; any `rsync error` / non-zero EXIT called out
3. Only then start **`rsync-data-to-zusb` on f1**

## 9. `rsync-data-to-zusb` (k3svolumes → zusb) on f1

Right after **Run `~/Syncthing/**/rsync-data-to-usb` on earth**. As root on
f1, run the NFS→zusb rsync driver on the mounted `zusb` pool:

`/opt/snonux/bin/backup/rsync-data-to-zusb`

It `rsync -av --delete`s selected k3svolumes (player libraries, navidrome,
forgejo, immich, …) into `/srv/data/enc/…` on `zusb`. Requires zusb mounted
(**Mount `zusb`…** / `/opt` available). Takes a while — **detach with
`nohup`** so it survives laptop disconnect; keep a pointer file to track it.

### How to update `rsync-data-to-zusb`

Edit **in place** on the f-host that currently has `zusb` loaded (usually
**f1** during the quarterly session). No f0 / zrepl round-trip — the script
rides on `zusb/data/opt` (`/opt`), not on the NFS replica.

1. **Stop** any in-flight run if you will re-run after editing:

   ```sh
   # on f1 (zusb host)
   doas pkill -f '/opt/snonux/bin/backup/rsync-data-to-zusb' || true
   doas pkill -f 'rsync -av --delete.*/data/nfs/k3svolumes' || true
   ```

2. **Edit in place** (backup first). Typical cloud-app line (dest
   `/srv/data/enc/cloud/`):

   ```sh
   SCRIPT=/opt/snonux/bin/backup/rsync-data-to-zusb
   doas cp -a "$SCRIPT" "${SCRIPT}.bak.$(date +%Y%m%d-%H%M%S)"
   # append or insert a line, e.g.:
   # rsync -av --delete --exclude '*.stfolder' \
   #   /data/nfs/k3svolumes/<volume> /srv/data/enc/cloud/
   doas "$EDITOR" "$SCRIPT"   # or tee -a as root
   ```

   Conventions: media libraries → matching
   `/srv/data/enc/{audiobooks,music,musicvideos,yoga,xman,…}`; forgejo →
   `/srv/data/enc/git/forgejo`; many small apps → `/srv/data/enc/cloud/`;
   immich → `/srv/data/enc/pictures/immich/` (with video exclude). Keep
   `set -x` at the top; prefer one `rsync` line per source.

3. **Start** with `nohup` (next subsection).

### Start (detached on f1, full stdout/stderr log)

```sh
# on f1 (or: ssh f1.lan …)
LOG=/tmp/rsync-data-to-zusb-$(date +%Y%m%d-%H%M%S).log
doas sh -c "cd / && nohup /opt/snonux/bin/backup/rsync-data-to-zusb >'$LOG' 2>&1 </dev/null & echo \$! > /tmp/rsync-data-to-zusb.pid"
sleep 2
PID=$(doas cat /tmp/rsync-data-to-zusb.pid)
doas sh -c "printf 'LOG=%s\nPID=%s\nSTARTED=%s\nHOST=f1\nCMD=nohup /opt/snonux/bin/backup/rsync-data-to-zusb\n' \
  '$LOG' '$PID' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > /tmp/rsync-data-to-zusb.latest"
doas ln -sfn "$LOG" /tmp/rsync-data-to-zusb.log
```

Agent: start once, confirm PID + log growth, then disconnect. Do not hold an
SSH session open for the whole rsync. Script uses `set -x`, so the log shows
each rsync invocation. **Do not start `backup start` until this job has
exited** (poll `pgrep` / the log; see pass criteria). Scrub may still be
running — that is fine.

### Inspect later

```sh
cat /tmp/rsync-data-to-zusb.latest
doas tail -f /tmp/rsync-data-to-zusb.log
pgrep -lf 'rsync-data-to-zusb|/data/nfs/k3svolumes'   # script and/or rsync children
```

### Pass criteria

1. `nohup` job started; `/tmp/rsync-data-to-zusb.latest` points at the live log
2. Process finishes (no `rsync-data-to-zusb` and no leftover k3svolumes rsync
   children); log ends without a hard failure on the last rsync (IO errors on
   known-bad files — note them; see prior immich runs)
3. Spot-check a few `/srv/data/enc/…` targets look updated
4. Only then proceed to **`backup start` on f1** (never overlap the two)

Started 2026-10-18 on f1 via `nohup` → `/tmp/rsync-data-to-zusb.log`
(canonical path `/opt/snonux/bin/backup/rsync-data-to-zusb` on zusb).

## 10. `backup start` on f1 (snapshots + S3)

Requires **Mount `zusb` on f1 + confirm enc keys** (`zusb` imported, `/opt`
mounted, AWS creds symlink resolving under `/root/.aws/credentials` →
`/opt/snonux/secrets/aws.credentials`). See [Backups & Local-Path](backups.md).

**Gate:** **`rsync-data-to-zusb` must be finished** (no process, pass criteria
above). Do **not** start this while that rsync (or its children) is still
running — snapshots would miss late writes and both jobs fight for disk. Scrub
may still be in progress; that overlap is allowed.

Runs `/opt/snonux/bin/backup/backup start` as root: creates dated ZFS send
archives under `/backup/<host>/<year>/` and `aws s3 sync`s them to
`s3://org-buetow-backup/` (Deep Archive). Takes hours — **must keep running on
f1 if the laptop disconnects or reboots**.

### Start (detached on f1, full stdout/stderr log)

Do **not** leave this attached to an SSH session from earth. Use `nohup` on
f1 with redirects; write a pointer file for later inspection:

```sh
# on f1 (or: ssh f1.lan …) — refuse if rsync-data-to-zusb (or children) still run
pgrep -lf 'rsync-data-to-zusb|rsync -av --delete.*/data/nfs/k3svolumes' \
  && { echo 'rsync-data-to-zusb still running; wait'; exit 1; }

LOG=/tmp/backup-start-$(date +%Y%m%d-%H%M%S).log
doas sh -c "cd / && nohup /opt/snonux/bin/backup/backup start >'$LOG' 2>&1 </dev/null & echo \$! > /tmp/backup-start.pid"
sleep 2
PID=$(doas cat /tmp/backup-start.pid)
doas sh -c "printf 'LOG=%s\nPID=%s\nSTARTED=%s\nHOST=f1\nCMD=nohup /opt/snonux/bin/backup/backup start\n' \
  '$LOG' '$PID' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > /tmp/backup-start.latest"
doas ln -sfn "$LOG" /tmp/backup-start.log
```

Agent: only after **`rsync-data-to-zusb` has exited**. SSH in once to start the
`nohup` job, confirm the log is growing and the process is alive, then
disconnect. Do **not** AwaitShell on a long local SSH that holds the session
open for the whole backup.

### Inspect later (after laptop reboot)

```sh
ssh f1.lan
cat /tmp/backup-start.latest          # LOG=… PID=…
doas tail -f /tmp/backup-start.log    # symlink to the active log
# or: doas tail -f "$(awk -F= '/^LOG=/{print $2}' /tmp/backup-start.latest)"

pgrep -lf '/opt/snonux/bin/backup/backup'   # still running?
doas tr '\r' '\n' < /tmp/backup-start.log | tail -n 40   # aws progress uses \r
```

`/tmp/backup-start.latest` is only a **pointer** (paths/pid) — the full
command output is in `LOG=` / `/tmp/backup-start.log`.

### Pass criteria

1. Process still running under `nohup` (or finished with a clean end in the log)
2. Log shows snapshot create/prepare/upload lines for the expected datasets
3. No hard failure left as the last lines (`error`, traceback, non-zero exit
   without completion); S3 uploads progress or complete for each archive dir
   under `/backup/f3s/<year>/`

Started 2026-10-18 on f1 via `nohup` →
`/tmp/backup-start-20261018-113456.log` (also `/tmp/backup-start.log`).

## 11. Verify background jobs, report errors, unload `zusb`

Final gate before unplugging the USB disks. Do **not** unload while scrub,
`rsync-data-to-zusb`, or `backup start` are still running.

### 1) Check all background work finished

```sh
# on f1
pgrep -lf '/opt/snonux/bin/backup/backup' && echo 'backup STILL RUNNING'
pgrep -lf 'rsync-data-to-zusb' && echo 'rsync-data-to-zusb STILL RUNNING'
pgrep -lf 'rsync -av --delete.*/(data/nfs/k3svolumes|srv/data/enc)' && echo 'rsync children STILL RUNNING'

doas zpool status zusb
# scrub done when scan line is: scrub repaired … with N errors on <date>
# still going: scrub in progress since …
```

All of: no backup process, no `rsync-data-to-zusb` (and no leftover k3svolumes
rsync children), scrub **completed** (not in progress).

### 2) Report errors from the logs

```sh
cat /tmp/backup-start.latest /tmp/rsync-data-to-zusb.latest

# backup (aws progress uses \r)
doas tr '\r' '\n' < /tmp/backup-start.log \
  | grep -iE 'error|fail|traceback|exception' | grep -viE 'error handling' || true
doas tr '\r' '\n' < /tmp/backup-start.log | tail -n 40

# rsync-data-to-zusb (set -x + rsync)
doas grep -iE 'error|fail|IO error|rsync error' /tmp/rsync-data-to-zusb.log || true
doas tail -n 40 /tmp/rsync-data-to-zusb.log

# scrub / pool permanent errors
doas zpool status -v zusb
```

Summarize for the user: hard failures vs known noise (e.g. pre-existing
permanent music-snap data error on `zusb`, transient aws progress lines).

### 3) Unload only if clean enough

If background jobs are done **and** there are no new blocking errors in the
backup/rsync logs (discuss known pool permanent errors with the user if
unsure), export and power down the disks:

```sh
# on f1 as root
doas /usr/local/bin/zusb-unload
```

Confirm `zpool list zusb` fails / pool gone. Do **not** unload if jobs are
still running or logs show a failed backup/rsync that still needs fixing.

Only if the user **explicitly** asks to unload before scrub finishes: pause
first (`doas zpool scrub -p zusb`), then `zusb-unload`. Do not make that the
default path.

### Pass criteria

1. Scrub finished; backup and rsync-data-to-zusb processes gone
2. Log review reported to the user (errors called out explicitly)
3. `zusb-unload` run only after (1)+(2) with no blocking failures; pool no
   longer imported

Then continue with **Start `rocky` VM on f1**.

## 12. Start `rocky` VM on f1

After **Verify background jobs… / `zusb-unload`** (or whenever the quarterly
session on f1 is otherwise finished), bring the VM back so normal workloads
resume.

```sh
# on f1
doas vm start rocky
doas vm list   # rocky … Running
```

### Pass criteria

1. `doas vm list` shows `rocky` as **Running**
2. Only run this after unload (or after the user ends the backup session early
   with scrub paused + unload) — not while heavy backup I/O is still needed
