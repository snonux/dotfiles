---
name: refresh-irregular-ninja
description: Regenerate the irregular.ninja photo album with the shuriken tool and sync it to both web servers. Use when the user asks to refresh, update, publish, sync, or deploy the irregular.ninja photo site. Triggers on, irregular ninja, refresh irregular, update photo album, sync irregular, deploy irregular.ninja.
---

# Refresh irregular.ninja

Regenerate the static photo album for `irregular.ninja` with the **shuriken**
tool and deploy it to both mirrors (`fishfinger.buetow.org` and
`blowfish.buetow.org`).

> The album was migrated from the old `photoalbum`/Makefile workflow to
> `shuriken`. There is no longer a `Makefile` or `photoalbumrc`; generation is
> driven entirely by `shuriken.conf`. Do not use `make` or `photoalbum`.

## When to Use

- Use when the user asks to refresh, update, publish, sync, or deploy `irregular.ninja`.
- Use when new photos have arrived in the `incoming/` symlink and the site needs rebuilding.
- Use when the user mentions irregular ninja, photo album, or the dist/ folder.

## Key Paths

- `~/git/irregular.ninja/irregular.ninja`: working directory containing `shuriken.conf`.
- `~/git/irregular.ninja/irregular.ninja/shuriken.conf`: the shuriken config (title, geometry,
  `IMAGE_JOBS`, `SHUFFLE=yes`, `SPLASH_PAGE=yes`, `INCOMING_DIR`, `DIST_DIR`,
  `TEMPLATE_DIR=/usr/share/shuriken/templates/default`). Read by `shuriken`
  automatically as `./shuriken.conf` — no `--config` flag needed.
- `~/git/irregular.ninja/irregular.ninja/incoming`: symlink to the Pixel 7 Pro camera folder
  (`/home/paul/Syncthing/Pixel7Pro/DCIM/Irregular Ninja/irregular.ninja`).
- `~/git/irregular.ninja/irregular.ninja/dist/`: generated output (HTML, photos, thumbs,
  blurs, `index.html`, `shuriken.json`).
- `~/git/irregular.ninja/irregular.ninja/cache/`: volatile per-photo EXIF identify
  cache (parallel to `dist/`). Persists across runs so unchanged photos skip the
  slow `identify`, making regenerates much faster. It is **not** part of the
  published site — never rsync it to the servers. Safe to delete (forces a full
  EXIF rebuild); `--clean` leaves it in place, `--force` clears it once per run.

## Workflow

1. **(Optional) Preview the plan** — confirm the config loads and see the photo
   count before writing anything:
   ```bash
   cd ~/git/irregular.ninja/irregular.ninja && shuriken --dry-run
   ```

2. **Generate** — run `shuriken --generate` from `~/git/irregular.ninja/irregular.ninja`:
   ```bash
   cd ~/git/irregular.ninja/irregular.ninja && shuriken --generate
   ```
   This reads `./shuriken.conf` and:
   - Scans the `incoming/` folder for supported images
   - Creates thumbs, blurs, and scaled derivatives (ImageMagick), skipping any
     that already exist
   - Re-renders all per-page and per-photo HTML, navigation redirects, and the
     `index.html` splash page
   - Writes `dist/shuriken.json` generation metadata

   Generation can be slow on a full run (the album has ~600+ photos); run it in
   the background and monitor the output if needed. To force a rebuild of
   existing thumbs/blurs from scratch, add `--force`.

3. **Sync to both servers** — rsync `dist/` to both mirrors with `--delete`:
   ```bash
   cd ~/git/irregular.ninja/irregular.ninja
   for foo in fishfinger blowfish; do
       rsync -av --delete dist/ admin@${foo}.buetow.org:/var/www/htdocs/irregular.ninja/
   done
   ```
   Only sync when the user asks to publish/deploy/sync; a plain "regenerate"
   request stops after step 2.

## Rules

1. Always run from `~/git/irregular.ninja/irregular.ninja`.
2. Use `shuriken`, not `make`/`photoalbum` (the old toolchain is gone).
3. Run `shuriken --generate` before syncing — never sync stale `dist/` output.
4. Use `rsync -av --delete` so removed photos are also removed from the servers.
5. `SHUFFLE=yes` with no `RANDOM_SEED`, so preview order changes every run; that
   is expected. Set `RANDOM_SEED` in `shuriken.conf` only if reproducible output
   is wanted.
6. The config's `TEMPLATE_DIR` points at the installed templates
   (`/usr/share/shuriken/templates/default`); a feature needing newer templates
   (e.g. a stats page) requires the installed `shuriken`/templates to be updated
   first.
7. Only `dist/` is deployed. Never rsync the `cache/` directory to the servers —
   it is a local build accelerator, not part of the published site.

## Expected Output

- `shuriken --generate` prints `Rendering <template> template into …/dist/…html`
  lines for every page, view, details, and redirect.
- New photos print `Creating …` thumb/derivative lines; existing photos are
  skipped silently.
- On success it exits 0 and `dist/` contains one `photos/`, `thumbs/`, `blurs/`
  entry per image plus the rendered HTML, `index.html`, and `shuriken.json`.
- rsync (when syncing) reports bytes sent and speedup for each host.
