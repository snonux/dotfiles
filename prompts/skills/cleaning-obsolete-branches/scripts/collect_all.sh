#!/usr/bin/env bash
# Run every read-only collector and write the TSVs into <datadir>.
# Takes a few minutes: one compare call per remote branch.
set -euo pipefail

datadir=${1:?usage: $0 <datadir> [dir-with-repos...]}
shift
(( $# )) || set -- "$HOME/git" "$HOME/git/gitsyncer-workdir"
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$datadir"

python3 "$here/collect_remote.py" github  > "$datadir/gh.tsv" 2> "$datadir/gh.err" &
python3 "$here/collect_remote.py" forgejo > "$datadir/fj.tsv" 2> "$datadir/fj.err" &
bash "$here/collect_local.sh" "$@"        > "$datadir/local.tsv" 2> "$datadir/local.err"
wait
python3 "$here/collect_remote.py" prs "$datadir/gh.tsv" > "$datadir/prs.tsv"

wc -l "$datadir"/*.tsv
# Collector errors (API timeouts, repos without a default branch) leave "?" in
# the data; such branches end up under REVIEW, never as delete candidates.
for err in "$datadir"/*.err; do
    [[ -s "$err" ]] && { echo "== $err"; cat "$err"; }
done
exit 0
