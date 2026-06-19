# cmus: re-index the library

cmus is a **C** program; it does **not** use Perl. **`lib.pl`** is only a **plain-text list of absolute paths** (one per line)—the suffix is cmus naming, not Perl source.

Library state lives under **`${XDG_CONFIG_HOME:-$HOME/.config}/cmus/`**:

| File | Role |
|------|------|
| `lib.pl` | Every track path cmus knows about |
| `cache` | Binary tag/metadata cache (safe to delete to force rescan) |
| `autosave` | Options and bindings (do not delete casually) |

After **beets `move`**, **tiddl** downloads, or any **tree reshuffle**, `lib.pl` can still list old paths until you re-index. Use the **same music root** as Navidrome (e.g. `/data/nfs/k3svolumes/navidrome/music`).

## Check before rewriting files

```bash
cmus-remote -Q 2>/dev/null || true   # expect "cmus is not running" for offline rewrite
```

## Offline re-index (cmus stopped)

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

## Live re-index (`cmus-remote`, cmus already running)

In the cmus `:` prompt, or:

```bash
cmus-remote -C 'clear -l'
cmus-remote -C 'add -l /data/nfs/k3svolumes/navidrome/music'
cmus-remote -C 'update-cache -f'
```

`update-cache -f` forces a full metadata refresh (same idea as deleting `cache`).

**Note:** the cmus UI wants a real TTY; `cmus-remote` only works when cmus is already running.

## After a full library maintenance pass

Typical order: **beets** (organize/tags) → **Navidrome** full scan → **cmus** re-index (offline script above, or `clear -l` / `add -l` / `update-cache -f`).
