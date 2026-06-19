---
name: photo-processing
description: "Process photo directories to detect duplicates, burst sequences, sharpness-ranked keepers, and cleanup candidates. Handles perceptual hashing, EXIF-based burst clustering, edge-sharpness scoring, Syncthing conflicts, and safe staged deletion. Use when asked to deduplicate photos, find blurry shots, clean up burst sequences, detect near-duplicates, or organize camera imports. Triggers on: photo cleanup, deduplicate images, find duplicates, burst shots, sharpness ranking, photo processing, camera import cleanup, remove blurry photos."
---

# Photo Processing

Clean up photo directories by detecting duplicates, burst sequences, and blurry/outlier frames. Provide actionable keep/delete recommendations with safe staged deletion.

## Reference Files

- [Auto-enhance](references/auto-enhance.md) — standalone ImageMagick 7 batch script (`auto-enhance-photos.sh`) for auto-orientation, auto-levels, auto-gamma, mild brightness/saturation. Use this to *improve* surviving keepers, separate from the culling workflow below.

## When to Use

- User asks to **deduplicate**, **find duplicates**, or **detect near-duplicates** in a photo folder.
- User asks to **clean up burst shots**, **shutter-speed sequences**, or **keep only sharpest** frames.
- User asks to **remove blurry photos**, **find out-of-focus shots**, or **rank by sharpness**.
- User mentions **Syncthing conflicts** in a photo directory.
- User imports a **camera card** or **Fujifilm/Canon/Sony/Nikon** folder and wants cleanup.
- Triggers: *photo cleanup*, *deduplicate images*, *find duplicates*, *burst shots*, *sharpness ranking*, *photo processing*, *camera import cleanup*, *remove blurry photos*.

## Required Tools

- `exiftool` — EXIF metadata extraction (timestamps, burst grouping)
- `python3` + `PIL/Pillow` — perceptual hashing, sharpness scoring
- `ImageFilter.FIND_EDGES` from Pillow — edge-based sharpness metric
- `fdupes` — exact byte-level duplicate detection (optional fallback)
- Standard shell tools (`ls`, `stat`, `md5sum`, `mv`, `mkdir`)

## Core Techniques

### 1. Exact Duplicate Detection

Run `fdupes -r -s -S <dir>` first. If it finds groups, those are byte-identical duplicates — safe to delete all but one without visual review.

### 2. Near-Duplicate Detection (Perceptual Hashing)

Use **average hash (aHash)** on a 16×16 grayscale resize:

```python
from PIL import Image

def ahash(path, size=16):
    with Image.open(path) as im:
        im = im.convert('L').resize((size, size), Image.Resampling.LANCZOS)
        pixels = list(im.getdata())
        avg = sum(pixels) / len(pixels)
        bits = ''.join('1' if p > avg else '0' for p in pixels)
        return int(bits, 2)

def hamming_distance(a, b):
    x = a ^ b
    dist = 0
    while x:
        dist += 1
        x &= x - 1
    return dist
```

- **hamming = 0**: identical or nearly identical
- **hamming ≤ 5**: very similar, likely burst variants
- **hamming ≤ 10**: similar composition, review recommended
- **hamming > 20**: different shots

Compare only nearby filename ranges (e.g., ±15 frames) to avoid O(n²) on large sets.

### 3. Burst Sequence Detection (EXIF Timestamp Clustering)

Use `exiftool -DateTimeOriginal -SubSecTimeOriginal` to extract capture time. Group frames where consecutive timestamps differ by ≤ 3 seconds. A burst is defined as ≥ 3 consecutive frames within that gap.

```python
from datetime import datetime
from collections import defaultdict

def parse_exif_datetime(raw):
    # 2026:06:07 13:19:22
    return datetime.strptime(raw, '%Y:%m:%d %H:%M:%S')
```

Also report **same-second shots** (≥ 2 frames with identical `HH:MM:SS`) — these are always burst/machine-gun frames.

### 4. Sharpness Ranking (Keep the Best, Delete the Rest)

Compute **variance of edge intensities** as a proxy for sharpness. A sharper image has stronger high-frequency detail, which shows up after `ImageFilter.FIND_EDGES`.

```python
from PIL import Image, ImageFilter

def sharpness_score(path):
    with Image.open(path) as im:
        im = im.convert('L').resize((1024, 1024), Image.Resampling.LANCZOS)
        edges = im.filter(ImageFilter.FIND_EDGES)
        pixels = list(edges.getdata())
        mean = sum(pixels) / len(pixels)
        var = sum((p - mean) ** 2 for p in pixels) / len(pixels)
        return var
```

Within each burst:
1. Compute sharpness for every frame
2. Sort descending by sharpness
3. Recommend **keeping top 2–5** depending on burst size
4. Label remainder as **delete candidates**

**File size as secondary signal:** larger JPEGs in a burst often correlate with more detail (less motion blur, higher complexity), but sharpness score is the primary metric.

### 5. Syncthing Conflict Handling

Files matching `*.sync-conflict-*.JPG` are Syncthing duplicates. For each conflict:
- Find the non-conflict original by stripping `.sync-conflict-<id>` from the basename
- Compare perceptual hashes:
  - If hamming ≈ 0: conflict is identical → delete the conflict
  - If hamming is small but sizes differ: keep the larger/better one, delete the other
  - If no original exists: the conflict is an orphan → move to `to_delete/` for manual review

### 6. Safe Staged Deletion Workflow

**Never delete immediately.** Always:

1. Compute all metrics and present a ranked summary to the user
2. Confirm the delete candidate list
3. `mkdir -p to_delete/`
4. `mv <candidates> to_delete/`
5. Report what was moved and total space freed
6. User can later `rm -rf to_delete/` after review, or `mv to_delete/* .` to restore

## Typical Workflow

1. **Scan directory** — count files, check for exact duplicates (`fdupes`)
2. **Hash all images** — compute aHash for perceptual similarity
3. **Extract EXIF timestamps** — group into burst sequences by time gaps ≤ 3s
4. **Compute sharpness** — rank each burst by edge variance
5. **Identify conflicts** — flag Syncthing orphans
6. **Present summary** — bursts found, keepers, delete candidates, space estimate
7. **Move to `to_delete/`** after user confirmation

## Output Format

For each burst, present:
- Burst size and time range
- Top N keepers with sharpness score + file size
- Bottom N delete candidates with sharpness score + file size
- Clear recommendation ("Keep top 3, delete the other 12")

## Caveats

- **Low-resolution thumbnails** or heavily compressed frames may have low file size but still be sharp — trust the sharpness score over size when they disagree.
- **Monochrome/B&W images** have different perceptual hash behavior than color; the edge-sharpness metric still works.
- **Portraits with shallow DOF** may have a blurry background but sharp subject. The global edge-variance metric can mis-rank these if the background dominates. For critical portrait bursts, the user should visually review the top-ranked frames rather than auto-deleting.
- **Different compositions** within a short time window (e.g. wide shot → close-up) may cluster as a single burst by timestamp. The hamming distance check catches this — if consecutive frames differ by > 20, they are different compositions and should not be auto-deleted.

## Auto-Enhancement

After culling, optionally improve the surviving keepers with the standalone ImageMagick batch script. See [references/auto-enhance.md](references/auto-enhance.md) for the full `auto-enhance-photos.sh` script, a per-flag explanation, output naming, and saturation tuning.
