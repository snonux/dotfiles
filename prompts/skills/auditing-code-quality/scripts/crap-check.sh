#!/usr/bin/env bash
# crap-check.sh: one command for the CRAP checks, with nothing to fill in.
#
#   crap-check.sh [BASE]    review mode: score the Go functions changed since
#                           BASE. Exit 2 if a function is at CRAP 30 or more
#                           and the change created it or raised its complexity.
#   crap-check.sh --all     audit mode: print the 20 highest-scoring functions
#                           of the whole module. Always exits 0 on success.
#
# Run it from the Go module root (the directory with go.mod). BASE defaults to
# the merge-base with the remote default branch, or HEAD~1 when there is none.
# It locates gocrap next to itself and keeps the coverprofile in a temp dir,
# so callers never need to know the skill's install path. Exit codes: 0 pass,
# 1 could not run, 2 limit exceeded. Failing tests do not
# stop the check (other packages still produce coverage), but they are reported.
set -euo pipefail

LIMIT=30
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[ -f go.mod ] || { echo "crap-check: run this from a Go module root (no go.mod here)" >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if ! go test -coverprofile="$tmp/cover.out" ./... >"$tmp/test.log" 2>&1; then
    echo "crap-check: WARNING: go test failed; coverage is incomplete. Last lines:" >&2
    tail -n 5 "$tmp/test.log" >&2
fi
cover=()
[ -s "$tmp/cover.out" ] && cover=(-cover "$tmp/cover.out")

# Build instead of `go run`: go run reports any failure as exit status 1 and
# would hide gocrap's exit 2 (limit exceeded) from the caller.
go -C "$here/gocrap" build -o "$tmp/gocrap" .

if [ "${1:-}" = "--all" ]; then
    "$tmp/gocrap" -root "$PWD" "${cover[@]}" -top 20
    exit 0
fi

base="${1:-}"
if [ -z "$base" ]; then
    base="$(git merge-base HEAD origin/HEAD 2>/dev/null || true)"
    # On the default branch itself the merge-base is HEAD: nothing to compare.
    if [ -z "$base" ] || [ "$base" = "$(git rev-parse HEAD)" ]; then
        base="HEAD~1"
    fi
fi
echo "crap-check: functions changed since $base (limit CRAP $LIMIT)" >&2
"$tmp/gocrap" -root "$PWD" "${cover[@]}" -changed "$base" -top 0 -fail-over "$LIMIT"
echo "crap-check: PASS" >&2
