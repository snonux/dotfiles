#!/usr/bin/env bash
# Harmless orchestration regression: every collector is a local shell stub.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
target=${1:-"$here/../collect_all.sh"}
fixture=$(mktemp -d)
_cleanup() {
    local pidfile pid
    # Also stop unfinished stubs when testing a broken wrapper that exits early.
    for pidfile in "$fixture"/cases/*/*.pid; do
        [[ -f "$pidfile" ]] || continue
        read -r pid < "$pidfile"
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    rm -rf "$fixture"
}
trap _cleanup EXIT
mkdir -p "$fixture/bin" "$fixture/scripts" "$fixture/cases"
cp "$target" "$fixture/scripts/collect_all.sh"

cat > "$fixture/bin/python3" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "$COLLECT_TEST_SCRIPTS/collect_remote.py" ]]
mode=$2
if [[ "$mode" == prs ]]; then
    [[ -f "$3" && -f "$COLLECT_TEST_CASE/github.done" \
        && -f "$COLLECT_TEST_CASE/forgejo.done" \
        && -f "$COLLECT_TEST_CASE/local.done" ]]
    touch "$COLLECT_TEST_CASE/prs.called"
    printf 'lodge\told-branch\tMERGED\t#1\n'
    exit 0
fi
printf '%s\n' "$$" > "$COLLECT_TEST_CASE/$mode.pid"
case "$mode" in
    github) status=$COLLECT_TEST_GITHUB; delay=0.05 ;;
    forgejo) status=$COLLECT_TEST_FORGEJO; delay=0.15 ;;
    *) exit 99 ;;
esac
sleep "$delay"
# Even a failed process can have emitted partial data; it must not reach PRs.
printf '%s\tlodge\tmain\told-branch\t2026-10-01\t?\t?\tabcdef\t\n' "$mode"
echo "$mode stub diagnostic: comparison unavailable (?)" >&2
touch "$COLLECT_TEST_CASE/$mode.done"
exit "$status"
STUB
chmod +x "$fixture/bin/python3"

cat > "$fixture/scripts/collect_local.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$#" == 1 && "$1" == "$COLLECT_TEST_CASE/repos with spaces" ]]
printf '%s\n' "$$" > "$COLLECT_TEST_CASE/local.pid"
sleep 0.02
printf 'lodge\tmain\tlocal\told-branch\t2026-10-01\t?\t?\t\n'
echo 'local stub diagnostic' >&2
touch "$COLLECT_TEST_CASE/local.done"
exit "$COLLECT_TEST_LOCAL"
STUB

_fail() {
    echo "FAIL: $*" >&2
    exit 1
}

_case() {
    local name=$1 github=$2 forgejo=$3 local_rc=$4 expected=$5
    local case_dir="$fixture/cases/$name" status=0 collector pid rc
    mkdir -p "$case_dir/data"
    printf 'stale PR inventory\n' > "$case_dir/data/prs.tsv"
    COLLECT_TEST_CASE="$case_dir" \
    COLLECT_TEST_SCRIPTS="$fixture/scripts" \
    COLLECT_TEST_GITHUB="$github" COLLECT_TEST_FORGEJO="$forgejo" \
    COLLECT_TEST_LOCAL="$local_rc" PATH="$fixture/bin:$PATH" \
        bash "$fixture/scripts/collect_all.sh" "$case_dir/data" \
        "$case_dir/repos with spaces" > "$case_dir/stdout" \
        2> "$case_dir/stderr" || status=$?
    [[ "$status" == "$expected" ]] \
        || _fail "$name: expected exit $expected, got $status"

    for collector in github forgejo local; do
        [[ -f "$case_dir/$collector.done" ]] \
            || _fail "$name: returned before $collector finished"
        read -r pid < "$case_dir/$collector.pid"
        if kill -0 "$pid" 2>/dev/null; then
            _fail "$name: $collector still running after wrapper returned"
        fi
        grep -Fq "$collector stub diagnostic" "$case_dir/stderr" \
            || _fail "$name: missing $collector stderr"
        case "$collector" in
            github) rc=$github ;;
            forgejo) rc=$forgejo ;;
            local) rc=$local_rc ;;
        esac
        if (( rc != 0 )); then
            grep -Fq "$collector collector failed (exit $rc)" \
                "$case_dir/stderr" \
                || _fail "$name: missing $collector exit status"
        fi
    done

    if (( expected != 0 )); then
        [[ ! -e "$case_dir/prs.called" && ! -e "$case_dir/data/prs.tsv" ]] \
            || _fail "$name: failed inventory published PR output"
        [[ ! -s "$case_dir/stdout" ]] \
            || _fail "$name: failed inventory printed successful counts"
        grep -Fq 'Collection failed: incomplete inventory' "$case_dir/stderr" \
            || _fail "$name: missing incomplete-inventory warning"
    else
        [[ -e "$case_dir/prs.called" && -s "$case_dir/data/prs.tsv" ]] \
            || _fail "$name: successful inventory did not collect PRs"
        grep -Fq "$case_dir/data/prs.tsv" "$case_dir/stdout" \
            || _fail "$name: missing inventory counts"
        grep -Fq $'\t?\t?\t' "$case_dir/data/gh.tsv" \
            || _fail "$name: successful partial API row was lost"
        if grep -Fq 'collector failed' "$case_dir/stderr"; then
            _fail "$name: successful collector reported as failed"
        fi
    fi
    echo "PASS: $name"
}

_case github-failure 23 0 0 1
_case forgejo-failure 0 24 0 1
_case both-remote-failures 23 24 0 1
_case local-failure 0 0 25 1
_case all-failures 23 24 25 1
_case success-with-partial-api-row 0 0 0 0
