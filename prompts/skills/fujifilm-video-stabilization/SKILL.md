---
name: fujifilm-video-stabilization
description: "Stabilize shaky Fujifilm X100V videos (DSCF*.MOV) using ffmpeg's 2-pass vidstab filter and encode compact 4K HEVC MP4 output. Handles motion detection, transform and sharpening, Intel VAAPI acceleration with a software fallback, cleanup, verification, and batch processing. Use when asked to stabilize video, reduce camera shake, smooth handheld footage, compress stabilized video, or process Fujifilm X100V MOV files. Triggers on: stabilize video, reduce camera shake, vidstab, ffmpeg stabilization, Fujifilm X100V, compress video, smooth footage, handheld video."
---

# Fujifilm X100V Video Stabilization

2-pass ffmpeg vidstab workflow to remove camera shake from Fujifilm X100V `.MOV` clips.
Outputs compact 4K HEVC `.mp4` files; cleans up temp `.trf` files when done.

## When to Use

- User wants to **stabilize shaky video** or **reduce camera shake**
- Source files are Fujifilm X100V `.MOV` clips (e.g. `DSCF7259.MOV`)
- User asks to **process multiple clips** in a folder
- Triggers: *stabilize video*, *reduce shake*, *vidstab*, *smooth handheld footage*

## Required Tools

- `ffmpeg` with `libvidstab` enabled (verify: `ffmpeg -filters 2>/dev/null | grep vidstab`)
- Intel VAAPI HEVC support through `/dev/dri/renderD128` (preferred)
- Input location: `/home/paul/syncthing/Documents/Inbox/Fujifilm/` (typical)

## 2-Pass Workflow

### Pass 1 — Motion Detection

Analyze each clip and write transform data to a `.trf` file:

```bash
ffmpeg -y -i DSCF7259.MOV -vf vidstabdetect=result=DSCF7259.trf -f null -
```

- `vidstabdetect` uses default parameters (`shakiness=5`, `accuracy=15`) — these work well for typical X100V handheld clips.
- `-f null -` discards output; only the `.trf` sidecar is produced.
- Run pass 1 for all clips **before** starting pass 2 (they can run in parallel if CPU allows).

### Pass 2 — Stabilize, Sharpen, and Compress

Apply transforms, add a mild unsharp pass, and encode directly to a compact HEVC MP4:

```bash
ffmpeg -y -vaapi_device /dev/dri/renderD128 -i DSCF7259.MOV \
  -map 0:v:0 -map "0:a:0?" \
  -vf "vidstabtransform=input=DSCF7259.trf,unsharp=5:5:0.8:3:3:0.4,format=nv12,hwupload" \
  -c:v hevc_vaapi -rc_mode CQP -global_quality 34 -tag:v hvc1 \
  -c:a aac -b:a 128k -movflags +faststart stabilised-DSCF7259.mp4
```

- `unsharp=5:5:0.8:3:3:0.4` — luma and chroma unsharp with mild strength (0.8 / 0.4); compensates for the slight softening vidstab introduces.
- VAAPI performs the expensive 4K HEVC encode on the Intel GPU.
- Quality 34 reduces typical stabilized videos by roughly 80% while retaining 4K resolution. Use 30–32 when higher quality is more important than size.
- AAC audio and `hvc1` tagging provide broad MP4 compatibility. `faststart` makes remote playback begin sooner.
- Output is named `stabilised-<original>.mp4` to keep it alongside the source.

If VAAPI is unavailable, use software HEVC encoding instead (this is substantially slower):

```bash
ffmpeg -y -i DSCF7259.MOV -map 0:v:0 -map "0:a:0?" \
  -vf "vidstabtransform=input=DSCF7259.trf,unsharp=5:5:0.8:3:3:0.4" \
  -c:v libx265 -preset medium -crf 28 -tag:v hvc1 \
  -c:a aac -b:a 128k -movflags +faststart stabilised-DSCF7259.mp4
```

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

# Pass 2 — serial to avoid overloading the GPU
for f in *.MOV; do
  base="${f%.MOV}"
  ffmpeg -y -vaapi_device /dev/dri/renderD128 -i "$f" \
    -map 0:v:0 -map "0:a:0?" \
    -vf "vidstabtransform=input=${base}.trf,unsharp=5:5:0.8:3:3:0.4,format=nv12,hwupload" \
    -c:v hevc_vaapi -rc_mode CQP -global_quality 34 -tag:v hvc1 \
    -c:a aac -b:a 128k -movflags +faststart \
    "stabilised-${base}.mp4"
done

rm -f *.trf
```

## Verify Output

Check duration and file size of stabilized clips:

```bash
for f in stabilised-*.mp4; do
  echo -n "$f: "
  ffprobe -v error -show_entries format=duration,size -of csv=p=0 "$f"
  ffmpeg -v error -i "$f" -f null -
done
```

## Notes

- **Syncthing caveat**: the `Fujifilm` folder is synced. If files vanish mid-session, Syncthing may have moved them after detecting completion. Check `~/.local/share/syncthing/` or other sync peers.
- **Quality**: default vidstab params produce good results for typical X100V handheld footage. For extremely shaky video, add `shakiness=10:accuracy=15` to the pass 1 filter.
- **Output size**: HEVC quality 34 reduced a 334 MB stabilized test clip to 58 MB without changing its 3840×2160 resolution or duration.
- **Avoid intermediate encodes**: encode the stabilized MP4 directly from the camera `.MOV`. Do not first create a VP9 MKV and then transcode it, because that wastes time and adds generation loss.
