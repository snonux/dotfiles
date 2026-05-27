#!/usr/bin/env bash
# Transcode every *.flac in SRCDIR to a CD-audio WAV in DSTDIR
# (44.1 kHz / 16-bit signed / stereo little-endian PCM).
set -euo pipefail
src=${1:?usage: flac_to_cdwav.sh SRCDIR DSTDIR}
dst=${2:?usage: flac_to_cdwav.sh SRCDIR DSTDIR}
mkdir -p "$dst"
rm -f "$dst"/*.wav
shopt -s nullglob
count=0
for f in "$src"/*.flac; do
    base=$(basename "$f" .flac)
    out="$dst/$base.wav"
    ffmpeg -nostdin -loglevel error -y -i "$f" \
           -ar 44100 -ac 2 -sample_fmt s16 -f wav "$out"
    count=$((count+1))
done
echo "Wrote $count WAV files to $dst"
