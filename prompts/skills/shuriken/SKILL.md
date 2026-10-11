---
name: shuriken
description: "Generates a lean shuriken photo album (no tarball, no stats site, no per-photo details pages) from a directory of photos and publishes it to /var/www/html/fotos on pi0.lan and pi1.lan. Use when asked to build and publish a photo album from an input directory. Triggers on: shuriken album, generate photo album, publish fotos, new photo album."
disable-model-invocation: true
---

# Shuriken photo album

Turn a directory of photos into a static [shuriken](https://github.com/snonux/shuriken.sh)
album and publish it to the two home web servers. One script does both steps:
`scripts/shuriken_album.sh`.

## When to Use

- A new batch of photos should become an album under `/fotos/` on `pi0.lan`
  and `pi1.lan`
- An existing album needs regenerating and re-publishing from its photo
  directory

## Inputs

| Input | Required | Meaning |
|-------|----------|---------|
| `INDIR` | yes | Directory holding the source photos. |
| `ALBUM_NAME` | yes | Album title **and** remote folder name, e.g. `so.war.das.bis.september.2026`. Letters, digits, `.`, `_`, `-` only. |
| `DIST_DIR` | no | Output directory. Defaults to `dist` next to `INDIR`. |

The user supplies `INDIR`. If they did not give an album name, **ask for it**;
do not derive it from the path (existing albums follow no single naming
scheme: `ls /var/www/html/fotos` on `pi0.lan` shows them).

## Workflow

1. **Check the input.** `INDIR` must exist and contain photos. If it is empty,
   look for the photos nearby and ask which directory was meant rather than
   generating an empty album.
2. **Run the script** in the background (850 photos took about 40 minutes
   with details pages; without them the HTML phase is roughly half as long):
   ```sh
   scripts/shuriken_album.sh INDIR ALBUM_NAME [DIST_DIR]
   ```
   It generates with `--no-tarball --no-stats --no-details`, then rsyncs
   `DIST_DIR/` to both servers and verifies each one (file count matches the
   local album, splash page answers HTTP 200).
3. **Report** the two URLs it prints, plus any `WARNING:` lines from shuriken
   (unreadable EXIF only costs that photo its tooltip).

### Options

- `--clean` wipes a non-empty `DIST_DIR` first (`shuriken --clean`). Needed
  when `DIST_DIR` still holds a *different* album. It deletes that directory,
  so confirm with the user before passing it.
- `--keep` generates into a non-empty `DIST_DIR`; only for re-running the
  *same* album (existing thumbnails and blurs are reused).
- `--no-sync` generates only. Publishing is the default because the skill is
  invoked deliberately; use this when the user wants to look first.

Without either of the first two, a non-empty `DIST_DIR` aborts the run.

## How it works and why

- **Config.** shuriken refuses to run without a config file. The script uses
  the installed `/etc/default/shuriken` and overrides everything
  album-specific on the command line, so nothing is written into the photo
  directory. To exercise a source checkout instead, set `SHURIKEN`,
  `SHURIKEN_CONF` and `SHURIKEN_TEMPLATE` (see the script header).
- **Staging.** `DIST_DIR` stays empty until the very end; shuriken builds in a
  `.shuriken.dist.staging.*` sibling and swaps it in. An empty `DIST_DIR`
  mid-run is normal. A `cache/` sibling (EXIF cache) also appears.
- **Sync.** The docroot is root-owned on both NetBSD hosts, so the script
  rsyncs with `--rsync-path='doas /usr/pkg/bin/rsync'`; no `mkdir`/`chown`
  step is needed. `pi0.lan` goes first because `pi1.lan` mirrors pi0's docroot
  hourly with `--delete` and re-owns `fotos` to root; details in the
  [`f3s` skill](../f3s/references/raspberry-pi/netbsd-bozohttpd.md).
- **Never `shuriken --sync` here.** That publishes to the `SYNC_DESTINATIONS`
  of a config file, which this workflow does not use.
