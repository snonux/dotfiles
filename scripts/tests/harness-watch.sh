#!/usr/bin/env bash
# Checks for scripts/harness-watch status: prints "(none)" when no "A-" pane
# exists, even though tmux itself succeeds (kg4). Uses a fake tmux on PATH and
# a temporary HOME, so the real tmux server and ~/.cache stay untouched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../harness-watch"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'harness-watch test: %s\n' "$*" >&2
    exit 1
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home"

# Fake tmux: "list-panes" prints the contents of $FAKE_PANES; any other
# subcommand fails so a stray capture-pane/send-keys would be noticed.
cat >"$TEST_ROOT/bin/tmux" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == list-panes ]]; then
    cat "$FAKE_PANES" 2>/dev/null || exit 1 # missing file: "no server"
    exit 0
fi
exit 1
EOF
chmod +x "$TEST_ROOT/bin/tmux"

run_status() {
    HOME="$TEST_ROOT/home" PATH="$TEST_ROOT/bin:$PATH" \
        FAKE_PANES="$TEST_ROOT/panes" "$TARGET" status
}

# Only non-"A-" sessions: tmux succeeds, nothing matches -> "(none)".
printf 'B-x %%1 claude\nmain %%2 fish\n' >"$TEST_ROOT/panes"
out=$(run_status)
grep -qx '  (none)' <<<"$out" \
    || fail "no A- panes: expected '  (none)', got: ${out}"
grep -q 'B-x' <<<"$out" && fail "non-A- pane listed: ${out}"

# No panes at all (empty tmux output) -> "(none)".
: >"$TEST_ROOT/panes"
out=$(run_status)
grep -qx '  (none)' <<<"$out" \
    || fail "empty pane list: expected '  (none)', got: ${out}"

# tmux itself fails (no server) -> "(none)", and status still exits 0.
rm -f "$TEST_ROOT/panes"
out=$(run_status) || fail "status failed when tmux failed"
grep -qx '  (none)' <<<"$out" \
    || fail "tmux failure: expected '  (none)', got: ${out}"

# Negative: an "A-" pane is listed and "(none)" is not printed.
printf 'A-x %%3 claude\nB-x %%1 claude\nA-y %%4 fish\n' >"$TEST_ROOT/panes"
out=$(run_status)
grep -qx '  A-x%3' <<<"$out" || fail "A-x pane not listed: ${out}"
grep -qx '  A-y%4 (skipped: fish)' <<<"$out" \
    || fail "skipped A-y pane not listed: ${out}"
grep -q '(none)' <<<"$out" && fail "'(none)' printed with A- panes: ${out}"

printf 'harness-watch tests passed\n'
