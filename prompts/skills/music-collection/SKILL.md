---
name: music-collection
description: >-
  Organizes, deduplicates, and tags local music with beets; triggers Navidrome
  library rescans (including Kubernetes); re-indexes cmus; downloads from Tidal
  with tiddl. Use when the user works on a music library, Navidrome, cmus, beets,
  duplicate tracks, folder layout, full scan, or Tidal downloads (tiddl).
---

# Music collection (beets, Navidrome, cmus, tiddl)

## Principles

- **Sort/organize** = consistent tags + path templates + `beet move` (or import with `move`).
- **Dedup** = find candidates by audio fingerprint or metadata keys, then delete or merge deliberately—never bulk-delete without confirming criteria.
- **Navidrome** picks up changes after a **library scan** (paths and tags on disk).
- **cmus** stores paths in `lib.pl` (text, not Perl) and tags in `cache`; re-index after path churn (see **cmus** section).
- **tiddl** is third-party; personal-use only; respect Tidal ToS and local law.

---

## Beets: layout and “sorting”

1. Point `directory` at the library root (the folder Navidrome mounts as music).
2. Define `paths` (e.g. genre → album artist → album → track). Use `$albumartist`, `$album%aunique{}`, `$track`, `$title`.
3. **Stable genre folders**: use the **inline** plugin with a computed field (e.g. `safe_genre`) that returns `Miscellaneous` when `genre` is empty and applies `.title()` so `electronic` and `Electronic` share one folder on case-sensitive filesystems.
4. **Import** (non-interactive batch): `beet import -A -m -q --quiet-fallback=asis PATH` (`-m` move, `-A` skip autotag for speed, `-q` no prompts). For MusicBrainz tagging, omit `-A` (slower).
5. After changing `paths` or inline fields: `beet move` to apply templates to items already in the DB.
6. **Permissions**: if the music volume is not writable as the current user, run `beet` with elevated permissions or fix ownership; keep the **beets database** under the user’s home (e.g. `-c /path/to/config.yaml` and `library:` in that file).

---

## Beets: deduplication

Enable the **duplicates** plugin in config (`plugins: duplicates`) and configure how “same track” is defined.

- **By audio content (strong)**: use `duplicates: checksum: ffmpeg` (or another backend per beets docs) so identical audio is detected even if tags differ.
- **By metadata (weaker)**: keys such as `mb_trackid` or `fingerprint`—fast but misses true dupes with bad tags.

Workflow:

1. `beet duplicates -c` (or equivalent) to **count** / preview groups—consult `beet duplicates --help` for the installed beets version.
2. Inspect a few groups (paths, tags, bitrate).
3. Remove or merge only after explicit criteria (e.g. keep highest bitrate, or keep file already under the canonical path template). Prefer `beet remove` / `beet modify` on a **narrow query** over blind `-d` flags.

Optional: **import** with `duplicate_action` / incremental import settings to reduce future dupes.

---

## Navidrome: full rescan

Navidrome reflects **on-disk** paths and embedded tags after a scan.

### Same host as the music volume

If the `navidrome` binary is available and paths match the server:

```bash
navidrome scan --full --datafolder /path/to/data --musicfolder /path/to/music --cachefolder /path/to/cache -l info -n
```

Use the same `--datafolder`, `--musicfolder`, and `--cachefolder` as the running server (see process env e.g. `ND_DATAFOLDER`, `ND_MUSICFOLDER`, or deployment mounts).

### Kubernetes (exec into the pod)

Long scans can **outlive `kubectl exec`**; run **detached** inside the container so API disconnects do not kill the scan:

```bash
kubectl exec -n NAMESPACE POD -- sh -c \
  'nohup /app/navidrome scan --full --datafolder /data --musicfolder /music --cachefolder /data/cache -l info -n >> /data/scan-manual.log 2>&1 &'
```

Monitor:

```bash
kubectl exec -n NAMESPACE POD -- tail -f /data/scan-manual.log
```

**Caveat:** scanner and server share the SQLite DB; if corruption or locking appears, run scan with Navidrome stopped (deployment scaled to 0), then start again.

---

## cmus: re-index the library

cmus is a **C** program; it does **not** use Perl. **`lib.pl`** is only a **plain-text list of absolute paths** (one per line)—the suffix is cmus naming, not Perl source.

Library state lives under **`${XDG_CONFIG_HOME:-$HOME/.config}/cmus/`**:

| File | Role |
|------|------|
| `lib.pl` | Every track path cmus knows about |
| `cache` | Binary tag/metadata cache (safe to delete to force rescan) |
| `autosave` | Options and bindings (do not delete casually) |

After **beets `move`**, **tiddl** downloads, or any **tree reshuffle**, `lib.pl` can still list old paths until you re-index. Use the **same music root** as Navidrome (e.g. `/data/nfs/k3svolumes/navidrome/music`).

### Check before rewriting files

```bash
cmus-remote -Q 2>/dev/null || true   # expect "cmus is not running" for offline rewrite
```

### Offline re-index (cmus stopped)

Timestamped backup, regenerate `lib.pl`, remove `cache`:

```bash
set -e
MUSIC=/data/nfs/k3svolumes/navidrome/music
CMUS="${XDG_CONFIG_HOME:-$HOME/.config}/cmus"
TS=$(date +%Y%m%d-%H%M%S)

cp -a "$CMUS/lib.pl" "$CMUS/lib.pl.bak.$TS"
test -f "$CMUS/cache" && cp -a "$CMUS/cache" "$CMUS/cache.bak.$TS" || true

find "$MUSIC" -type f \( \
  -iname '*.flac' -o -iname '*.mp3' -o -iname '*.m4a' -o -iname '*.ogg' \
  -o -iname '*.opus' -o -iname '*.wav' -o -iname '*.wv' -o -iname '*.mpc' \
  -o -iname '*.aac' \
\) 2>/dev/null | LC_ALL=C sort -u >"$CMUS/lib.pl.tmp"
mv "$CMUS/lib.pl.tmp" "$CMUS/lib.pl"
rm -f "$CMUS/cache"
```

Start cmus afterward; the **first launch** may take a while while the cache rebuilds.

### Live re-index (`cmus-remote`, cmus already running)

In the cmus `:` prompt, or:

```bash
cmus-remote -C 'clear -l'
cmus-remote -C 'add -l /data/nfs/k3svolumes/navidrome/music'
cmus-remote -C 'update-cache -f'
```

`update-cache -f` forces a full metadata refresh (same idea as deleting `cache`).

**Note:** the cmus UI wants a real TTY; `cmus-remote` only works when cmus is already running.

### After a full library maintenance pass

Typical order: **beets** (organize/tags) → **Navidrome** full scan → **cmus** re-index (offline script above, or `clear -l` / `add -l` / `update-cache -f`).

---

## tiddl: Tidal downloads

[tiddl](https://github.com/oskvr37/tiddl) is a Python CLI (PyPI: `tiddl`). Requires **ffmpeg** for transcoding.

**Install:** `uv tool install tiddl` or `pip install tiddl` (see project README for current Python version requirements).

**Auth (once):**

```bash
tiddl auth login
```

**Download by URL or short id:**

```bash
tiddl download url 'https://tidal.com/browse/track/...'
tiddl download url 'album/123456789'
tiddl download url 'playlist/...' --skip-errors
```

### Batch download from a list file (`tidal.txt`)

Put one playlist/album/track URL or short id per line (e.g. `playlist/…`, `https://listen.tidal.com/…`).

**Fish outer, bash inner:** The interactive shell is **fish**; each line runs in **`bash -c`** so `source …/bin/activate` works (Python venv activation is bash/POSix-oriented). Fish owns the loop and closes with **`end`**; there is no `do`/`done` in fish—only the inner bash sees a one-shot `-c` script.

```fish
cat tidal.txt | while read -l playlist
    bash -c 'source ~/git/upstream/tiddl/.venv/bin/activate && tiddl download url "$1" --skip-errors' _ "$playlist"
end
```

- Use **`"$1"`** with a dummy **`$0`** (`_`) so the URL/id is one argument even with spaces.
- Add `--skip-errors` inside the single-quoted `bash -c` string if you want the batch to continue past bad playlist entries.
- Optionally skip blanks or `#` lines before calling `bash -c` (e.g. `string trim`, `string match -q '#*'`).

**Pure bash/zsh (optional):** If you are already in bash, activating the venv **once** then looping avoids one bash subprocess per line:

```bash
source ~/git/upstream/tiddl/.venv/bin/activate
while IFS= read -r playlist || [[ -n "$playlist" ]]; do
  [[ -z "${playlist// }" || "$playlist" =~ ^[[:space:]]*# ]] && continue
  tiddl download url "$playlist" --skip-errors
done < tidal.txt
```

**Quality:** configure in `~/.tiddl/config.toml` (LOW / NORMAL / HIGH / MAX → m4a or flac per docs).

**Output layout:** set templates in config so downloads land under the same root beets/Navidrome use (e.g. artist/album/track), reducing later `beet import` churn.

After downloading, run **beets import** (and/or **Navidrome scan**) and **cmus re-index** as above.

---

## Quick reference

| Goal | Tool | Command / note |
|------|------|----------------|
| Rename/move to template | beets | `beet move` after `paths` / inline fields |
| Fix genre folder casing | beets | `safe_genre` with `.title()` + `beet move` |
| Tag files from DB | beets | `beet write` |
| Find duplicate files | beets | `duplicates` plugin + `beet duplicates …` |
| Refresh Navidrome DB | navidrome | `navidrome scan --full` with correct folders |
| Re-index cmus | cmus | Offline: backup `lib.pl`/`cache`, `find` → `lib.pl`, `rm cache`; live: `cmus-remote -C 'clear -l'` then `add -l ROOT` then `update-cache -f` |
| Download from Tidal | tiddl | `tiddl auth login` → `tiddl download url …` |

---

## Optional deep dive

For beets duplicate plugin options and checksum backends, read the official beets documentation for the installed version when tuning `duplicates:` in config.
