---
name: music-collection
description: >-
  Organizes, deduplicates, and tags local music with beets; triggers Navidrome
  library rescans (including Kubernetes); re-indexes cmus; downloads from Tidal
  with tiddl. Use when the user works on a music library, Navidrome, cmus, beets,
  duplicate tracks, folder layout, full scan, or Tidal downloads (tiddl).
---

# Music collection (beets, Navidrome, cmus, tiddl)

Maintain a local music library end to end: organize and tag with **beets**,
deduplicate, refresh the **Navidrome** server (on a host or in Kubernetes),
re-index **cmus**, and pull new tracks from **Tidal** with **tiddl**.

## Principles

- **Sort/organize** = consistent tags + path templates + `beet move` (or import with `move`).
- **Dedup** = find candidates by audio fingerprint or metadata keys, then delete or merge deliberately—never bulk-delete without confirming criteria.
- **Navidrome** picks up changes after a **library scan** (paths and tags on disk).
- **cmus** stores paths in `lib.pl` (text, not Perl) and tags in `cache`; re-index after path churn.
- **tiddl** is third-party; personal-use only; respect Tidal ToS and local law.

## Core workflow

A full library maintenance pass runs in this order:

**beets** (organize/tags + dedup) → **Navidrome** full scan → **cmus** re-index.
After **tiddl** downloads, rerun the same chain (import → scan → re-index).

## Reference Files

Detailed reference documentation is in the `references/` subfolder:

- [Beets: layout & dedup](references/beets-layout-and-dedup.md) — `directory`/`paths` templates, the inline `safe_genre` field for stable genre folders, non-interactive `beet import`, `beet move`, permissions; the `duplicates` plugin (audio checksum vs metadata keys) and a careful remove/merge workflow.
- [Navidrome: full rescan](references/navidrome-rescan.md) — `navidrome scan --full` with matching `--datafolder`/`--musicfolder`/`--cachefolder`; the detached `nohup … &` pattern for scans inside a Kubernetes pod via `kubectl exec`, log monitoring, and the shared-SQLite locking caveat.
- [cmus: re-index](references/cmus-reindex.md) — what `lib.pl`/`cache`/`autosave` are, the offline backup-and-regenerate script (`find` → `lib.pl`, `rm cache`), and the live `cmus-remote` path (`clear -l` / `add -l` / `update-cache -f`).
- [tiddl: Tidal downloads](references/tiddl-downloads.md) — install/auth, `tiddl download url …`, the fish-outer/bash-inner batch loop over `tidal.txt` (and a pure-bash variant), quality and output-layout config.

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
