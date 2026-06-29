---
name: fujifilm-video-stabilization
description: "Stabilize shaky Fujifilm X100V videos (DSCF*.MOV) using ffmpeg's 2-pass vidstab filter. Handles pass 1 (motion detection → .trf), pass 2 (transform + unsharp), cleanup of temp files, and batch processing of multiple clips. Use when asked to stabilize video, reduce camera shake, smooth handheld footage, or process Fujifilm X100V MOV files. Triggers on: stabilize video, reduce camera shake, vidstab, ffmpeg stabilization, Fujifilm X100V, smooth footage, handheld video."
---

# Fujifilm X100V Video Stabilization

2-pass ffmpeg vidstab workflow to remove camera shake from Fujifilm X100V `.MOV` clips.
Outputs stabilized `.mkv` files; cleans up temp `.trf` files when done.

## When to Use

- User wants to **stabilize shaky video** or **reduce camera shake**
- Source files are Fujifilm X100V `.MOV` clips (e.g. `DSCF7259.MOV`)
- User asks to **process multiple clips** in a folder
- Triggers: *stabilize video*, *reduce shake*, *vidstab*, *smooth handheld footage*

## Required Tools

- `ffmpeg` with `libvidstab` enabled (verify: `ffmpeg -filters 2>/dev/null | grep vidstab`)
- Input location: `/home/paul/syncthing/Documents/Inbox/Fujifilm.Videos/` (typical)

## 2-Pass Workflow

### Pass 1 — Motion Detection

Analyze each clip and write transform data to a `.trf` file:

```bash
ffmpeg -y -i DSCF7259.MOV -vf vidstabdetect=result=DSCF7259.trf -f null -
```

- `vidstabdetect` uses default parameters (`shakiness=5`, `accuracy=15`) — these work well for typical X100V handheld clips.
- `-f null -` discards output; only the `.trf` sidecar is produced.
- Run pass 1 for all clips **before** starting pass 2 (they can run in parallel if CPU allows).

### Pass 2 — Stabilize & Sharpen

Apply transforms and add a mild unsharp pass (FFmpeg's own recommendation):

```bash
ffmpeg -y -i DSCF7259.MOV \
  -vf "vidstabtransform=input=DSCF7259.trf,unsharp=5:5:0.8:3:3:0.4" \
  stabilised-DSCF7259.mkv
```

- `unsharp=5:5:0.8:3:3:0.4` — luma and chroma unsharp with mild strength (0.8 / 0.4); compensates for the slight softening vidstab introduces.
- Output is named `stabilised-<original>.mkv` to keep it alongside the source.

### Cleanup

Remove temp transform files after both passes succeed:

```bash
rm -f *.trf
```

## Batch Processing

For all `.MOV` files in the current directory, run pass 1 in parallel, then pass 2 serially:

```bash
# Pass 1 — all clips in parallel
for f in *.MOV; do
  base="${f%.MOV}"
  ffmpeg -y -i "$f" -vf vidstabdetect=result="${base}.trf" -f null - &
done
wait

# Pass 2 — serial (CPU-heavy; one at a time is fine)
for f in *.MOV; do
  base="${f%.MOV}"
  ffmpeg -y -i "$f" \
    -vf "vidstabtransform=input=${base}.trf,unsharp=5:5:0.8:3:3:0.4" \
    "stabilised-${base}.mkv"
done

rm -f *.trf
```

## Verify Output

Check duration and file size of stabilized clips:

```bash
for f in stabilised-*.mkv; do
  echo -n "$f: "
  ffprobe -v error -show_entries format=duration,size -of csv=p=0 "$f"
done
```

## Notes

- **Syncthing caveat**: the `Fujifilm.Videos` folder is synced. If files vanish mid-session, Syncthing may have moved them after detecting completion. Check `~/.local/share/syncthing/` or other sync peers.
- **Quality**: default vidstab params produce good results for typical X100V handheld footage. For extremely shaky video, add `shakiness=10:accuracy=15` to the pass 1 filter.
- **Output size**: stabilized `.mkv` files are re-encoded; expect ~10–15 MB/s for X100V clips at the default encoder quality (crf 23).
