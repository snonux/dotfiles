#!/usr/bin/env bash
# Checks for scripts/temp-backup quoting, errexit, and missing-source safety (j33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TEMP_BACKUP="${SCRIPT_DIR}/../temp-backup"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'temp-backup test: %s\n' "$*" >&2
    exit 1
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home" "$TEST_ROOT/calls"

# Mock rsync: one NUL-argv dump file per invocation; never sync for real.
cat >"$TEST_ROOT/bin/rsync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${RSYNC_CALL_DIR:?RSYNC_CALL_DIR unset}"
declare -i n
n=$(find "$RSYNC_CALL_DIR" -maxdepth 1 -type f -name 'call.*' | wc -l)
declare -r out="$RSYNC_CALL_DIR/call.${n}"
printf '%s\0' "$@" >"$out"
EOF
chmod +x "$TEST_ROOT/bin/rsync"

export PATH="$TEST_ROOT/bin:$PATH"
export HOME="$TEST_ROOT/home"
export TEMP_BACKUP_HOST='mock.host'
export RSYNC_CALL_DIR="$TEST_ROOT/calls"

reset_calls() {
    rm -f "$RSYNC_CALL_DIR"/call.*
}

call_count() {
    find "$RSYNC_CALL_DIR" -maxdepth 1 -type f -name 'call.*' | wc -l
}

read_call_argv() {
    local -r idx="$1"
    local -n _out="$2"
    mapfile -d '' -t _out <"$RSYNC_CALL_DIR/call.${idx}"
}

bash -n "$TEMP_BACKUP" || fail "bash -n failed"
shellcheck -x "$TEMP_BACKUP" || fail "shellcheck failed"

# Structural guards: strict mode, no set -x, quoted rsync source.
grep -q 'set -euo pipefail' "$TEMP_BACKUP" || fail "missing set -euo pipefail"
if grep -Eq '^[[:space:]]*set[[:space:]]+-x' "$TEMP_BACKUP"; then
    fail "script still enables set -x (path leakage)"
fi
# Reject the pre-fix unquoted one-liner (task j33 / SC2046).
# shellcheck disable=SC2016
if grep -Fq 'rsync -av --delete $dir' "$TEMP_BACKUP"; then
    fail "pre-fix unquoted rsync \$dir form still present"
fi
# shellcheck disable=SC2016
if grep -Fq '$(basename $dir)' "$TEMP_BACKUP"; then
    fail "basename \$dir still unquoted"
fi

# --- Positive: default dirs ---
mkdir -p "$HOME/Syncthing/Notes" "$HOME/Documents"
: >"$HOME/Syncthing/Notes/note.txt"
: >"$HOME/Documents/doc.txt"

reset_calls
"$TEMP_BACKUP" || fail "default run failed"
[[ "$(call_count)" -eq 2 ]] || fail "expected 2 rsync calls, got $(call_count)"

# --- Positive: path with spaces remains a single argv ---
declare -r SPACE_DIR="$TEST_ROOT/dir with spaces and \$HOME"
mkdir -p "$SPACE_DIR"
: >"$SPACE_DIR/file.txt"
declare -r SPACE_SRC="${SPACE_DIR}/"

reset_calls
"$TEMP_BACKUP" "$SPACE_SRC" || fail "space-path run failed"
[[ "$(call_count)" -eq 1 ]] || fail "expected 1 rsync call, got $(call_count)"

declare -a argv=()
read_call_argv 0 argv

declare -i found_src=0 found_dest=0 found_delete=0
declare -i i
for ((i = 0; i < ${#argv[@]}; i++)); do
    case "${argv[i]}" in
        --delete) found_delete=1 ;;
        "$SPACE_SRC") found_src=1 ;;
        "mock.host:tempbackup/dir with spaces and \$HOME") found_dest=1 ;;
    esac
done
((found_delete == 1)) || fail "--delete missing from rsync argv: ${argv[*]@Q}"
((found_src == 1)) || fail "source path not a single rsync argv: ${argv[*]@Q}"
((found_dest == 1)) || fail "dest path not a single rsync argv: ${argv[*]@Q}"

# --- Negative: missing source must fail before --delete rsync ---
reset_calls
if "$TEMP_BACKUP" "$TEST_ROOT/does-not-exist/" 2>"$TEST_ROOT/err"; then
    fail "missing source succeeded"
fi
grep -qi 'does not exist' "$TEST_ROOT/err" \
    || fail "missing source error unclear: $(cat "$TEST_ROOT/err")"
[[ "$(call_count)" -eq 0 ]] \
    || fail "rsync invoked despite missing source (--delete risk)"

# --- Negative: one missing among several — no rsync at all ---
reset_calls
if "$TEMP_BACKUP" "$SPACE_SRC" "$TEST_ROOT/missing-other/" \
    2>"$TEST_ROOT/err2"; then
    fail "partial missing sources succeeded"
fi
[[ "$(call_count)" -eq 0 ]] \
    || fail "rsync ran before all sources were validated"

# --- Negative: source is a file, not a directory ---
declare -r NOT_DIR="$TEST_ROOT/not-a-dir"
: >"$NOT_DIR"
reset_calls
if "$TEMP_BACKUP" "$NOT_DIR" 2>"$TEST_ROOT/err3"; then
    fail "file source succeeded"
fi
grep -qi 'not a directory' "$TEST_ROOT/err3" \
    || fail "non-dir error unclear: $(cat "$TEST_ROOT/err3")"
[[ "$(call_count)" -eq 0 ]] || fail "rsync ran for non-directory source"

# --- Negative: unquoted rsync form word-splits (documents the bug) ---
declare -r SPLIT_DIR="$TEST_ROOT/split me"
mkdir -p "$SPLIT_DIR"
reset_calls
# Intentional buggy expansion (do not quote).
# shellcheck disable=SC2086,SC2046
rsync -av --delete $SPLIT_DIR \
    "mock.host:tempbackup/$(basename $SPLIT_DIR)" || true
declare -a buggy_argv=()
read_call_argv 0 buggy_argv
declare -i saw_split=0
for ((i = 0; i < ${#buggy_argv[@]}; i++)); do
    if [[ "${buggy_argv[i]}" == "$TEST_ROOT/split" ]]; then
        saw_split=1
    fi
done
((saw_split == 1)) || fail "buggy repro did not word-split as expected"

printf 'temp-backup test: ok\n'
