---
name: burning-audio-cd
description: Burns a Red Book audio CD-R from a directory of FLAC files on a Fedora Linux host. Converts each FLAC to 44.1 kHz / 16-bit / stereo WAV with ffmpeg, then writes them as CD-DA tracks with cdrskin in DAO mode. Use when the user asks to burn, write, or master an audio CD / CD-R / CD-RW from FLACs, or mentions a CD writer / DVD-RW USB drive with a music folder to put on it. Triggers on, burn audio CD, burn CD-R, master audio CD, write FLAC to CD, audio CD from FLAC.
---

# Burning audio CD-Rs from FLAC files

End-to-end recipe for turning a folder of FLACs (already ordered and sized to
fit on the disc, e.g. the output of `creating-cd-mixes`) into a real Red Book
audio CD on Fedora Linux. The pipeline is: probe → install tools → transcode
FLAC→WAV → burn with `cdrskin` → eject and clean up.

## Tools

- `cdrskin` (libburn family) — burner. Install with `sudo dnf install -y cdrskin`.
- `ffmpeg` / `ffprobe` — transcoding and duration probing. Already present on
  most Fedora installs (`ffmpeg-free` or `ffmpeg` from RPM Fusion).

Do NOT try to `dnf install ffmpeg` blindly — Fedora has both `ffmpeg-free` and
RPM-Fusion `ffmpeg`, and asking dnf to install the second one over the first
fails with a conflict. Just verify `ffmpeg`/`ffprobe` are on PATH and skip
installing if so.

## Workflow

1. **Identify the drive.** Run `lsblk` and look for an `sr*` device, or
   `cdrskin --devices`. Confirm the disc is blank/erasable with:
   ```bash
   cdrskin dev=/dev/sr0 -minfo | tail -20
   ```
   Note the *Remaining writable size* in sectors (1 sec audio = 75 sectors;
   80-min disc ≈ 359,844 sectors).

2. **Verify the source fits.** Sum FLAC durations with `ffprobe` and confirm
   the total ≤ disc length (74 or 80 min). If unsure, run
   `scripts/probe_durations.sh /path/to/dir`.

3. **Transcode FLAC → CD-audio WAV** into a tmp dir using
   `scripts/flac_to_cdwav.sh /path/to/flacs /tmp/cd-burn`. Each WAV is
   44.1 kHz / 16-bit / stereo little-endian PCM with a standard RIFF header
   (cdrskin auto-detects and strips the 44-byte header).

4. **Burn.** Run `scripts/burn_audio_cd.sh /tmp/cd-burn /dev/sr0 [speed]`
   (default speed 16). It invokes:
   ```bash
   cdrskin dev=$DEV speed=$SPEED -v -force -dao -audio -pad <wavs sorted>
   ```
   - `-audio` switches to CD-DA mode (no ISO9660).
   - `-pad` zero-pads the last sector of each track.
   - `-dao` writes Disc-At-Once so there are no 2-second gaps between tracks.
   - `-force` is required because cdrskin's *predicted session size* check is
     overly conservative (adds ~50,000 sectors of headroom) and refuses
     near-full 80-min discs even when the actual content fits. The real fit is
     determined from the `Total size` / `Lout start` figures cdrskin prints
     just before burning — those must be ≤ disc capacity.

5. **Verify, eject, clean up.**
   ```bash
   eject /dev/sr0
   rm -rf /tmp/cd-burn
   ```

## Gotchas

- Audio-CD capacity is **time**, not bytes. Always reason in sectors/minutes,
  never in MB.
- Track order on the finished CD is the lexicographic order of the WAV
  filenames at burn time. Keep the `NN - Title.flac` numbering when
  transcoding.
- Filenames with spaces / Unicode are fine for cdrskin but must be quoted in
  shell loops. The scripts here use `find -print0` / `xargs -0` style safety.
- The first attempted burn often fails with
  `FATAL : predicted session size NNNNNs does not fit on media`. Re-run with
  `-force` if the actual `Lout start` sector count is within the disc's
  *Remaining writable size*.
- Some drives (e.g. HL-DT-ST DVDRAM GUE0N) silently bump write speed up after
  the first track or two; this is normal.

## Scripts

- `scripts/probe_durations.sh DIR` — prints each FLAC's duration and total.
- `scripts/flac_to_cdwav.sh SRCDIR DSTDIR` — clears DSTDIR and transcodes
  every `*.flac` in SRCDIR to a CD-audio WAV with the same basename.
- `scripts/burn_audio_cd.sh WAVDIR DEV [SPEED]` — burns every `*.wav` in
  WAVDIR to DEV as an audio CD (DAO, padded, forced).
