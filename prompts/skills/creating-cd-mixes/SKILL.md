---
name: creating-cd-mixes
description: "Builds themed audio-CD mixes from FLAC files in the local music library. Picks tracks from the user's chosen genres/folders, shuffles, deduplicates, and packs them into N discs that fit a 74-min or 80-min CD-R/RW; copies FLACs to ~/Desktop/Music and writes a .txt tracklist per disc. Use when the user asks to burn/create/prepare audio CDs, CD-R, CD-RW, mix CDs, or compile FLACs for a CD player. Triggers on: burn CD, mix CD, audio CD, CD-R, CD-RW, compile FLACs for CD."
---

# Creating CD mixes

Prepare FLAC playlists shaped for a physical audio CD: pick a theme, gather
candidate tracks from the music library, shuffle, and pack into N discs that
will fit a real CD-R/RW when burned as an **audio CD** (the burning tool
transcodes FLAC → PCM).

## Defaults for this user

- Music root: `/data/nfs/k3svolumes/navidrome/music`
- Output:     `~/Desktop/Music`
- Disc size:  ask if not specified
  - **74-min** CD-R/RW → use `max_seconds: 4380` (73:00, ~1 min headroom)
  - **80-min** CD-R/RW → use `max_seconds: 4700` (78:20, ~1:40 headroom)

Always leave headroom (60-100 s); burners reject overflowing tracks.

## Workflow

1. **Clarify** with the user, only if missing:
   - theme / genre (e.g. focus, deep house, lounge, classical, soundtrack)
   - number of discs (default 3 if the user says "a few")
   - disc length (74 vs 80 min)
2. **Survey the library**: list candidate FLAC source folders under the music
   root that match the theme. Use `find ... -iname "*.flac"` and `grep -i`
   with terms drawn from the theme. Confirm the picks with the user when the
   match is loose.
3. **Build a config** (see *Config schema* below). Prefer many small folders
   over one giant one so the shuffle feels varied.
4. **Run the packer**: pipe the JSON into `scripts/build_cds.py`. It writes
   `CD<N>-Mix/` folders plus `CD<N>-Mix.txt` summaries.
5. **Verify**: each disc's reported `Total time` must be ≤ the chosen limit.
   List the output dir and show a tracklist excerpt back to the user.
6. **Clean up** any earlier output directories before re-running so the user
   does not end up with stale CDs.

## Config schema

```json
{
  "music_root":  "/data/nfs/k3svolumes/navidrome/music",
  "dest":        "/home/paul/Desktop/Music",
  "title":       "Focus / House Mix",
  "num_cds":     3,
  "max_seconds": 4380,
  "seed":        42,
  "source_dirs": [
    "Miscellaneous/Compilations/Deep House Study Mix_ Electronic Music for Studying, Concentration",
    "Miscellaneous/Compilations/Chill House Cafe Playlist",
    "Miscellaneous/Polo & Pan/Cyclorama"
  ],
  "extra_files": [
    "Miscellaneous/David Guetta, Marten Hørger/The Freaks/01 The Freaks (Edit).flac"
  ]
}
```

- `source_dirs` are folders **relative to** `music_root`; every `*.flac`
  directly inside (non-recursive) is a candidate.
- `extra_files` add single tracks outside those folders.
- Tracks are deduplicated by lowercase title (after stripping a leading
  `"NN "` track-number prefix), so the same song appearing in two
  compilations only lands on one disc.

## Running the packer

```bash
python3 scripts/build_cds.py --config /tmp/mix.json
# or:
echo "$JSON" | python3 scripts/build_cds.py
```

Requires `ffprobe` (ffmpeg) on PATH for duration probing.

Output per disc:

```
~/Desktop/Music/CD1-Mix/
    01 - Track Title.flac
    02 - ...
~/Desktop/Music/CD1-Mix.txt        # tracklist + total time
```

## Burning

The user burns these as **audio CDs** with their preferred tool
(`brasero`, `k3b`, `xfburn`, etc.). The tool transcodes FLAC → 16-bit
44.1 kHz PCM automatically; the duration limit is what matters, not the
FLAC file size.

## Gotchas

- Audio-CD capacity is **time**, not bytes — never use folder size to
  decide what fits.
- Always re-check with `ffprobe` after picking tracks; tag-reported lengths
  can be wrong.
- The packer is greedy (places each shuffled track on the least-filled
  disc that still fits). It may leave a few long tracks unplaced; rerun
  with a different `seed` or fewer/more candidate folders if needed.
- Remove the previous `CD*-Mix` folders and `CD*.txt` files before each
  fresh run.
