---
name: refresh-irregular-ninja
description: Regenerate the irregular.ninja photo album and sync it to both web servers. Use when the user asks to refresh, update, publish, sync, or deploy the irregular.ninja photo site. Triggers on, irregular ninja, refresh irregular, update photo album, sync irregular, deploy irregular.ninja.
---

# Refresh irregular.ninja

Regenerate the static photo album for `irregular.ninja` and deploy it to both
mirrors (`fishfinger.buetow.org` and `blowfish.buetow.org`).

## When to Use

- Use when the user asks to refresh, update, publish, sync, or deploy `irregular.ninja`.
- Use when new photos have arrived in the `incoming/` symlink and the site needs rebuilding.
- Use when the user mentions irregular ninja, photo album, or the dist/ folder.

## Key Paths

- `~/Desktop/irregular.ninja`: working directory containing the Makefile and photoalbumrc.
- `~/Desktop/irregular.ninja/incoming`: symlink to the Pixel 7 Pro camera folder (`/home/paul/Syncthing/Pixel7Pro/DCIM/Irregular Ninja/irregular.ninja`).
- `~/Desktop/irregular.ninja/dist/`: generated output (HTML, photos, thumbs, blurs, index).

## Workflow

1. **Generate** — run `make` from `~/Desktop/irregular.ninja`:
   ```bash
   cd ~/Desktop/irregular.ninja && make
   ```
   This invokes `photoalbum generate photoalbumrc`, which:
   - Scans the `incoming/` folder for new images
   - Generates thumbs and blurs (ImageMagick)
   - Builds per-page and per-photo HTML
   - Updates navigation and `index.html`

2. **Sync to both servers** — rsync `dist/` to both mirrors with `--delete`:
   ```bash
   for foo in fishfinger blowfish; do
       rsync -av --delete dist/ admin@${foo}.buetow.org:/var/www/htdocs/irregular.ninja/
     done
   ```

## Rules

1. Always run from `~/Desktop/irregular.ninja`.
2. Run `make` before syncing — never sync stale `dist/` output.
3. Use `rsync -av --delete` so removed photos are also removed from the servers.
4. Expect ImageMagick v7 deprecation warnings (`convert` vs `magick`); these are harmless.

## Expected Output

- `make` prints generation progress per page and per photo.
- New photos show `Creating thumb …` and `Creating blur …` lines.
- Existing photos show `Already exists: …` and are skipped.
- rsync reports bytes sent and speedup for each host.
