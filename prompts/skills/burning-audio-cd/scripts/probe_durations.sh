#!/usr/bin/env bash
# Print duration of every *.flac in DIR and the total in MM:SS.
set -euo pipefail
dir=${1:?usage: probe_durations.sh DIR}
total=0
shopt -s nullglob
for f in "$dir"/*.flac; do
    d=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$f")
    printf "%7.2f  %s\n" "$d" "$(basename "$f")"
    total=$(awk -v a="$total" -v b="$d" 'BEGIN{printf "%.3f", a+b}')
done
mm=$(awk -v t="$total" 'BEGIN{printf "%d", t/60}')
ss=$(awk -v t="$total" -v m="$mm" 'BEGIN{printf "%05.2f", t - m*60}')
printf -- "----\nTOTAL: %s seconds (%d:%s)\n" "$total" "$mm" "$ss"
