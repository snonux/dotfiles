# Beets: layout, sorting, and deduplication

## Beets: layout and "sorting"

1. Point `directory` at the library root (the folder Navidrome mounts as music).
2. Define `paths` (e.g. genre → album artist → album → track). Use `$albumartist`, `$album%aunique{}`, `$track`, `$title`.
3. **Stable genre folders**: use the **inline** plugin with a computed field (e.g. `safe_genre`) that returns `Miscellaneous` when `genre` is empty and applies `.title()` so `electronic` and `Electronic` share one folder on case-sensitive filesystems.
4. **Import** (non-interactive batch): `beet import -A -m -q --quiet-fallback=asis PATH` (`-m` move, `-A` skip autotag for speed, `-q` no prompts). For MusicBrainz tagging, omit `-A` (slower).
5. After changing `paths` or inline fields: `beet move` to apply templates to items already in the DB.
6. **Permissions**: if the music volume is not writable as the current user, run `beet` with elevated permissions or fix ownership; keep the **beets database** under the user's home (e.g. `-c /path/to/config.yaml` and `library:` in that file).

## Beets: deduplication

Enable the **duplicates** plugin in config (`plugins: duplicates`) and configure how "same track" is defined.

- **By audio content (strong)**: use `duplicates: checksum: ffmpeg` (or another backend per beets docs) so identical audio is detected even if tags differ.
- **By metadata (weaker)**: keys such as `mb_trackid` or `fingerprint`—fast but misses true dupes with bad tags.

Workflow:

1. `beet duplicates -c` (or equivalent) to **count** / preview groups—consult `beet duplicates --help` for the installed beets version.
2. Inspect a few groups (paths, tags, bitrate).
3. Remove or merge only after explicit criteria (e.g. keep highest bitrate, or keep file already under the canonical path template). Prefer `beet remove` / `beet modify` on a **narrow query** over blind `-d` flags.

Optional: **import** with `duplicate_action` / incremental import settings to reduce future dupes.

## Optional deep dive

For beets duplicate plugin options and checksum backends, read the official beets documentation for the installed version when tuning `duplicates:` in config.
