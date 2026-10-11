#!/usr/bin/env bash
# Run every read-only collector and write the TSVs into <datadir>.
# Takes a few minutes: one compare call per remote branch.
set -euo pipefail

datadir=${1:?usage: $0 <datadir> [dir-with-repos...]}
shift
(( $# )) || set -- "$HOME/git" "$HOME/git/gitsyncer-workdir"
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$datadir"
# A failed rerun must not leave a previous PR inventory looking current.
rm -f "$datadir/prs.tsv"

failed=0
_report_failure() {
    echo "$1 collector failed (exit $2)" >&2
    failed=1
}

python3 "$here/collect_remote.py" github  > "$datadir/gh.tsv" 2> "$datadir/gh.err" &
github_pid=$!
python3 "$here/collect_remote.py" forgejo > "$datadir/fj.tsv" 2> "$datadir/fj.err" &
forgejo_pid=$!
bash "$here/collect_local.sh" "$@" \
    > "$datadir/local.tsv" 2> "$datadir/local.err" \
    || _report_failure local "$?"
# Always reap both jobs, including when the local scan or the first wait fails.
wait "$github_pid" || _report_failure github "$?"
wait "$forgejo_pid" || _report_failure forgejo "$?"

# Individual API errors can still leave "?" rows for REVIEW on a successful
# collector run. A failed collector process instead invalidates the inventory.
for err in "$datadir/gh.err" "$datadir/fj.err" "$datadir/local.err"; do
    if [[ -s "$err" ]]; then
        { echo "== $err"; cat "$err"; } >&2
    fi
done
if (( failed )); then
    echo "Collection failed: incomplete inventory; do not classify it." >&2
    exit 1
fi

python3 "$here/collect_remote.py" prs "$datadir/gh.tsv" > "$datadir/prs.tsv"
wc -l "$datadir"/*.tsv
exit 0
