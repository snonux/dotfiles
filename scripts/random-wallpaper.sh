#!/bin/sh
# Randomly sets a GNOME desktop wallpaper from image files in a given directory.

WALLPAPER_DIR="$HOME/Pictures/Pixel7ProDCIM/Irregular Ninja/irregular.ninja"

if [ ! -d "$WALLPAPER_DIR" ]; then
    printf 'Directory not found: %s\n' "$WALLPAPER_DIR" >&2
    exit 1
fi

# Pick a random image file (common extensions)
IMAGE=$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( \
    -iname '*.jpg' -o \
    -iname '*.jpeg' -o \
    -iname '*.png' -o \
    -iname '*.bmp' -o \
    -iname '*.webp' -o \
    -iname '*.gif' \
    \) | sort -R | head -n 1)

if [ -z "$IMAGE" ]; then
    printf 'No images found in %s\n' "$WALLPAPER_DIR" >&2
    exit 1
fi

# GNOME Shell caches wallpaper textures keyed by URI.
# If the path is always the same, Shell won't reload even when the file
# contents change. Use a unique filename on every run so the URI changes
# and Shell is forced to load the new image.
CLEAN_DIR="$HOME/.local/share/wallpapers"
UNIQUE="random-wallpaper-$(date +%s)"
CLEAN_PATH="$CLEAN_DIR/$UNIQUE.jpg"

mkdir -p "$CLEAN_DIR"
cp "$IMAGE" "$CLEAN_PATH"

# Clean up old copies to avoid filling the directory
# Keep the last 5 wallpapers around
ls -1t "$CLEAN_DIR"/random-wallpaper-*.jpg 2> /dev/null | sed -n '6,$p' | xargs -r rm -f

# dconf-service on Fedora 50 has a bug where gsettings set keeps changes in
# memory but never syncs them to the on-disk database.  GNOME Shell reads
# directly from disk, so it never sees wallpaper changes made with gsettings.
# Writing via dconf write bypasses the buggy service and hits the database
# directly, making GNOME Shell pick up the change immediately.
dconf write /org/gnome/desktop/background/picture-uri "'file://$CLEAN_PATH'"
dconf write /org/gnome/desktop/background/picture-uri-dark "'file://$CLEAN_PATH'"

# Show me what was set
printf 'Set wallpaper to: %s (copied from %s)\n' "$CLEAN_PATH" "$IMAGE"
