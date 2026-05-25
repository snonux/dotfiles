#!/usr/bin/env python3
"""Pack FLAC tracks into N audio CDs, shuffled and deduplicated by title.

Reads a JSON config from stdin or from --config FILE:

    {
      "music_root":  "/data/nfs/k3svolumes/navidrome/music",
      "dest":        "/home/paul/Desktop/Music",
      "name_prefix": "CD",     # output dirs become CD1-Mix, CD2-Mix, ...
      "name_suffix": "Mix",
      "title":       "Focus / House Mix",
      "num_cds":     3,
      "max_seconds": 4380,     # 73:00 — safe under 74-min CD limit
      "seed":        42,
      "source_dirs": [
        "Miscellaneous/Compilations/Deep House Study Mix_ Electronic Music for Studying, Concentration",
        "Miscellaneous/Compilations/Chill House Cafe Playlist"
      ],
      "extra_files": [
        "Miscellaneous/David Guetta, Marten Hørger/The Freaks/01 The Freaks (Edit).flac"
      ],
      "exclude_titles":   ["Eternal", "Tunnel"],   # optional: skip these (case-insensitive)
      "recursive":        false,                    # optional: glob *.flac recursively
      "start_index":      1                          # optional: start CD numbering (e.g. 2)
    }

Disc-length presets (max_seconds):
    74-min CD:  4380  (73:00, ~1 min headroom)
    80-min CD:  4700  (78:20, ~1:40 headroom)

Output per CD:
    <dest>/<name_prefix><N>-<name_suffix>/01 - Title.flac ...
    <dest>/<name_prefix><N>-<name_suffix>.txt   (summary)
"""

import argparse
import json
import random
import shutil
import subprocess
import sys
from pathlib import Path


def duration(p: Path) -> float:
    out = subprocess.check_output(
        ["ffprobe", "-v", "error",
         "-show_entries", "format=duration",
         "-of", "default=nw=1:nk=1", str(p)],
        text=True,
    )
    return float(out.strip())


def mmss(secs: float) -> str:
    m, s = divmod(int(round(secs)), 60)
    return f"{m}:{s:02d}"


def clean_title(stem: str) -> str:
    """Strip a leading 'NN ' track-number prefix."""
    if len(stem) > 3 and stem[:2].isdigit() and stem[2] == " ":
        return stem[3:].strip()
    return stem.strip()


def collect_pool(cfg: dict) -> list[dict]:
    music_root = Path(cfg["music_root"])
    recursive = bool(cfg.get("recursive", False))
    glob_pat = "**/*.flac" if recursive else "*.flac"
    paths: list[Path] = []
    for d in cfg.get("source_dirs", []):
        base = music_root / d
        if base.exists():
            paths.extend(sorted(base.glob(glob_pat)))
    for f in cfg.get("extra_files", []):
        p = music_root / f
        if p.exists():
            paths.append(p)

    excluded = {t.lower().strip() for t in cfg.get("exclude_titles", [])}
    seen: set[str] = set()
    pool: list[dict] = []
    for flac in paths:
        title = clean_title(flac.stem)
        key = title.lower()
        if key in seen or key in excluded:
            continue
        seen.add(key)
        pool.append({
            "path": flac,
            "title": title,
            "source": flac.parent.name,
            "duration": duration(flac),
        })
    return pool


def pack(pool: list[dict], num_cds: int, max_seconds: int):
    """Greedy fit into least-filled CD that still has room."""
    cds: list[list[dict]] = [[] for _ in range(num_cds)]
    totals = [0.0] * num_cds
    leftover: list[dict] = []
    for tr in pool:
        placed = False
        for i in sorted(range(num_cds), key=lambda x: totals[x]):
            if totals[i] + tr["duration"] <= max_seconds:
                cds[i].append(tr)
                totals[i] += tr["duration"]
                placed = True
                break
        if not placed:
            leftover.append(tr)
    return cds, totals, leftover


def write_cd(idx: int, tracks: list[dict], total: float, cfg: dict) -> None:
    dest = Path(cfg["dest"])
    prefix = cfg.get("name_prefix", "CD")
    suffix = cfg.get("name_suffix", "Mix")
    title = cfg.get("title", "Mix")
    max_s = cfg["max_seconds"]
    start = int(cfg.get("start_index", 1))
    name = f"{prefix}{idx + start}-{suffix}"
    out_dir = dest / name
    out_dir.mkdir(parents=True, exist_ok=True)

    summary = [
        f"CD {idx + start} — {title}",
        f"Total tracks: {len(tracks)}",
        f"Total time:   {mmss(total)} (limit {mmss(max_s)})",
        "",
        f"{'#':>2}  {'TIME':>5}  TITLE  [source]",
        "-" * 78,
    ]
    for i, tr in enumerate(tracks, 1):
        num = f"{i:02d}"
        dest_name = f"{num} - {tr['title']}.flac".replace("/", "_")
        shutil.copy2(tr["path"], out_dir / dest_name)
        summary.append(
            f"{num}  {mmss(tr['duration']):>5}  {tr['title']}  [{tr['source']}]"
        )
    (dest / f"{name}.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(f"  -> {name}: {len(tracks)} tracks, {mmss(total)}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", "-c", help="JSON config file (default: stdin)")
    args = ap.parse_args()

    raw = Path(args.config).read_text() if args.config else sys.stdin.read()
    cfg = json.loads(raw)

    cfg.setdefault("num_cds", 3)
    cfg.setdefault("max_seconds", 4380)
    cfg.setdefault("seed", 42)
    cfg.setdefault("title", "Mix")

    random.seed(cfg["seed"])
    Path(cfg["dest"]).mkdir(parents=True, exist_ok=True)

    pool = collect_pool(cfg)
    print(f"pool: {len(pool)} tracks, "
          f"{mmss(sum(t['duration'] for t in pool))} total")

    random.shuffle(pool)
    cds, totals, leftover = pack(pool, cfg["num_cds"], cfg["max_seconds"])
    if leftover:
        print(f"  leftover (did not fit): {len(leftover)}")
    for i, (tracks, total) in enumerate(zip(cds, totals)):
        write_cd(i, tracks, total, cfg)


if __name__ == "__main__":
    main()
