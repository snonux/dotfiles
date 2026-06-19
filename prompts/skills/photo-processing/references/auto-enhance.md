# Auto-Enhancement Script (Color, White Balance, Orientation)

A standalone Bash script using ImageMagick 7 to batch-process JPEGs with auto-orientation, auto-levels, auto-gamma, mild brightness boost, and conservative saturation. This is separate from the dedup/burst/sharpness core in the parent `SKILL.md` — use it when the user wants to *improve* the surviving keepers, not cull them.

## Script: `auto-enhance-photos.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-.}"
DIR="$(cd "$DIR" && pwd)"

mapfile -t files < <(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) | sort | while read -r f; do
    base="$(basename "$f")"
    [[ "$base" =~ -b\.[Jj][Pp][Ee]?[Gg]$ ]] && continue
    echo "$f"
done)

count="${#files[@]}"
[ "$count" -eq 0 ] && { echo "No JPEG files found."; exit 0; }

echo "Found $count image(s) to enhance."

processed=0; skipped=0; errors=0
for src in "${files[@]}"; do
    base="$(basename "$src")"
    if [[ "$base" =~ \.([Jj][Pp][Ee]?[Gg])$ ]]; then
        ext="${BASH_REMATCH[1]}"
        stem="${base%.$ext}"
        dst="$DIR/${stem}-b.${ext}"
    else
        dst="$DIR/${base}-b.jpg"
    fi

    [ -f "$dst" ] && { echo "SKIP  $base"; ((skipped++)) || true; continue; }

    echo "PROC  $base  ->  $(basename "$dst")"
    if magick "$src" \
        -auto-orient \
        -auto-level \
        -auto-gamma \
        -modulate 105,105 \
        -contrast-stretch 1%x1% \
        -quality 95 \
        "$dst" 2>/dev/null; then
        ((processed++)) || true
    else
        echo "ERR   $base"; ((errors++)) || true
    fi
done

echo "Done — Processed: $processed  Skipped: $skipped  Errors: $errors"
```

## What each operation does

| Flag | Effect |
|------|--------|
| `-auto-orient` | Reads EXIF `Orientation` tag and physically rotates the image if needed |
| `-auto-level` | Stretches the histogram to use the full tonal range (fixes mild under/over exposure) |
| `-auto-gamma` | Computes and applies an automatic gamma correction |
| `-modulate 105,105` | Increases brightness by 5% and saturation by 5%. *Adjust the second number to taste:* `100` = no saturation change, `110` = more vivid colors |
| `-contrast-stretch 1%x1%` | Slightly stretches shadows and highlights for extra pop |
| `-quality 95` | High-quality JPEG output to minimize re-compression artifacts |

## Output naming

Input `DSCF5854.JPG` → Output `DSCF5854-b.JPG` in the **same directory**.
Already-processed `-b` files are skipped on subsequent runs.

## Adjusting saturation

If the user finds results **too saturated**, lower the second number in `-modulate`:
```bash
-modulate 105,100   # brightness +5%, no saturation change
```

If the user wants **more vivid** results, raise it:
```bash
-modulate 105,115   # brightness +5%, saturation +15%
```
