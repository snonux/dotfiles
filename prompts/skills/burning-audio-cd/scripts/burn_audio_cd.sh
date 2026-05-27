#!/usr/bin/env bash
# Burn every *.wav in WAVDIR to DEV as a Red Book audio CD (DAO).
# Tracks are written in lexicographic filename order.
set -euo pipefail
wavdir=${1:?usage: burn_audio_cd.sh WAVDIR DEV [SPEED]}
dev=${2:?usage: burn_audio_cd.sh WAVDIR DEV [SPEED]}
speed=${3:-16}

mapfile -d '' -t wavs < <(find "$wavdir" -maxdepth 1 -type f -iname '*.wav' -print0 | sort -z)
if [ "${#wavs[@]}" -eq 0 ]; then
    echo "No WAV files in $wavdir" >&2
    exit 1
fi

echo "Burning ${#wavs[@]} tracks to $dev at speed $speed..."
cdrskin dev="$dev" speed="$speed" -v -force -dao -audio -pad "${wavs[@]}"
echo "Burn complete."
