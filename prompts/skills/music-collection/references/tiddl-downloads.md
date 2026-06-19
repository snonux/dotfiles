# tiddl: Tidal downloads

[tiddl](https://github.com/oskvr37/tiddl) is a Python CLI (PyPI: `tiddl`). Requires **ffmpeg** for transcoding.

**Note:** tiddl is third-party; personal-use only; respect Tidal ToS and local law.

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

## Batch download from a list file (`tidal.txt`)

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
