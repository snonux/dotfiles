#!/usr/bin/env bash
# Checks for scripts/temp-backup quoting, errexit, and dest-safety (j33).
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

# Real basename for the mock wrapper to delegate to (before PATH mock).
REAL_BASENAME="$(command -v basename)"
declare -r REAL_BASENAME

# basename mock: empty leaf for *empty-base* paths; else real basename.
cat >"$TEST_ROOT/bin/basename" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == -- && "\${2:-}" == *empty-base* ]]; then
    printf '\\n'
    exit 0
fi
exec '$REAL_BASENAME' "\$@"
EOF
chmod +x "$TEST_ROOT/bin/basename"

# Mock rsync: one NUL-argv dump file per invocation; never sync for real.
# Set RSYNC_FAIL_ON=N (0-based) to exit 1 after recording that call.
cat >"$TEST_ROOT/bin/rsync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${RSYNC_CALL_DIR:?RSYNC_CALL_DIR unset}"
declare -i n
n=$(find "$RSYNC_CALL_DIR" -maxdepth 1 -type f -name 'call.*' | wc -l)
declare -r out="$RSYNC_CALL_DIR/call.${n}"
printf '%s\0' "$@" >"$out"
if [[ -n "${RSYNC_FAIL_ON:-}" && "$n" -eq "$RSYNC_FAIL_ON" ]]; then
    exit 1
fi
EOF
chmod +x "$TEST_ROOT/bin/rsync"

export PATH="$TEST_ROOT/bin:$PATH"
export HOME="$TEST_ROOT/home"
export TEMP_BACKUP_HOST='mock.host'
export RSYNC_CALL_DIR="$TEST_ROOT/calls"

reset_calls() {
    rm -f "$RSYNC_CALL_DIR"/call.*
    unset RSYNC_FAIL_ON || true
}

call_count() {
    find "$RSYNC_CALL_DIR" -maxdepth 1 -type f -name 'call.*' | wc -l
}

read_call_argv() {
    local -r idx="$1"
    local -n _out="$2"
    mapfile -d '' -t _out <"$RSYNC_CALL_DIR/call.${idx}"
}

assert_rsync_shape() {
    local -r idx="$1"
    local -r want_src="$2"
    local -r want_dest="$3"
    local -a argv=()
    read_call_argv "$idx" argv

    declare -i found_src=0 found_dest=0 found_delete=0 found_sep=0
    declare -i i
    for ((i = 0; i < ${#argv[@]}; i++)); do
        case "${argv[i]}" in
            --delete) found_delete=1 ;;
            --) found_sep=1 ;;
            "$want_src") found_src=1 ;;
            "$want_dest") found_dest=1 ;;
        esac
    done
    ((found_delete == 1)) || fail "call $idx: --delete missing: ${argv[*]@Q}"
    ((found_sep == 1)) || fail "call $idx: -- separator missing: ${argv[*]@Q}"
    ((found_src == 1)) || fail "call $idx: source != ${want_src@Q}: ${argv[*]@Q}"
    ((found_dest == 1)) || fail "call $idx: dest != ${want_dest@Q}: ${argv[*]@Q}"
}

bash -n "$TEMP_BACKUP" || fail "bash -n failed"
shellcheck -x "$TEMP_BACKUP" || fail "shellcheck failed"

# Structural guards: strict mode, no set -x, basename --, quoted rsync.
grep -q 'set -euo pipefail' "$TEMP_BACKUP" || fail "missing set -euo pipefail"
if grep -Eq '^[[:space:]]*set[[:space:]]+-x' "$TEMP_BACKUP"; then
    fail "script still enables set -x (path leakage)"
fi
grep -Fq 'basename --' "$TEMP_BACKUP" || fail "missing basename -- (leading-dash safety)"
# Reject the pre-fix unquoted one-liner (task j33 / SC2046).
# shellcheck disable=SC2016
if grep -Fq 'rsync -av --delete $dir' "$TEMP_BACKUP"; then
    fail "pre-fix unquoted rsync \$dir form still present"
fi
# shellcheck disable=SC2016
if grep -Fq '$(basename $dir)' "$TEMP_BACKUP"; then
    fail "basename \$dir still unquoted"
fi

# --- Positive: default dirs — argv shape (source/dest/--delete) ---
mkdir -p "$HOME/Syncthing/Notes" "$HOME/Documents"
: >"$HOME/Syncthing/Notes/note.txt"
: >"$HOME/Documents/doc.txt"

reset_calls
"$TEMP_BACKUP" || fail "default run failed"
[[ "$(call_count)" -eq 2 ]] || fail "expected 2 rsync calls, got $(call_count)"
assert_rsync_shape 0 \
    "$HOME/Syncthing/Notes/" \
    "mock.host:tempbackup/Notes"
assert_rsync_shape 1 \
    "$HOME/Documents/" \
    "mock.host:tempbackup/Documents"

# --- Positive: trailing-slash normalization (content sync) ---
declare -r NOSLASH_DIR="$TEST_ROOT/noslash-dir"
mkdir -p "$NOSLASH_DIR"
: >"$NOSLASH_DIR/file.txt"

reset_calls
"$TEMP_BACKUP" "$NOSLASH_DIR" || fail "noslash run failed"
[[ "$(call_count)" -eq 1 ]] || fail "expected 1 rsync call, got $(call_count)"
assert_rsync_shape 0 \
    "${NOSLASH_DIR}/" \
    "mock.host:tempbackup/noslash-dir"

# --- Positive: path with spaces remains a single argv ---
declare -r SPACE_DIR="$TEST_ROOT/dir with spaces and \$HOME"
mkdir -p "$SPACE_DIR"
: >"$SPACE_DIR/file.txt"
declare -r SPACE_SRC="${SPACE_DIR}/"

reset_calls
"$TEMP_BACKUP" "$SPACE_SRC" || fail "space-path run failed"
[[ "$(call_count)" -eq 1 ]] || fail "expected 1 rsync call, got $(call_count)"
assert_rsync_shape 0 \
    "$SPACE_SRC" \
    "mock.host:tempbackup/dir with spaces and \$HOME"

# --- Positive: leading-dash dirname via basename -- ---
declare -r DASH_DIR="$TEST_ROOT/-dashy"
mkdir -p "$DASH_DIR"
: >"$DASH_DIR/file.txt"

reset_calls
"$TEMP_BACKUP" "$DASH_DIR" || fail "leading-dash run failed"
[[ "$(call_count)" -eq 1 ]] || fail "expected 1 rsync call for dash dir"
assert_rsync_shape 0 \
    "${DASH_DIR}/" \
    "mock.host:tempbackup/-dashy"

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

# --- Negative: refuse remote basename . ---
declare -r DOT_BASE="$TEST_ROOT/dotbase"
mkdir -p "$DOT_BASE"
reset_calls
if "$TEMP_BACKUP" "${DOT_BASE}/." 2>"$TEST_ROOT/err_dot"; then
    fail "basename . source succeeded"
fi
grep -qi 'refused remote basename' "$TEST_ROOT/err_dot" \
    || fail "dot basename error unclear: $(cat "$TEST_ROOT/err_dot")"
[[ "$(call_count)" -eq 0 ]] || fail "rsync ran for basename ."

# --- Negative: refuse remote basename .. ---
declare -r DOTDOT_BASE="$TEST_ROOT/dotdotbase/leaf"
mkdir -p "$DOTDOT_BASE"
reset_calls
if "$TEMP_BACKUP" "${DOTDOT_BASE}/.." 2>"$TEST_ROOT/err_dotdot"; then
    fail "basename .. source succeeded"
fi
grep -qi 'refused remote basename' "$TEST_ROOT/err_dotdot" \
    || fail "dotdot basename error unclear: $(cat "$TEST_ROOT/err_dotdot")"
[[ "$(call_count)" -eq 0 ]] || fail "rsync ran for basename .."

# --- Negative: refuse filesystem root ---
reset_calls
if "$TEMP_BACKUP" / 2>"$TEST_ROOT/err_root"; then
    fail "filesystem root source succeeded"
fi
grep -qi 'refusing filesystem root' "$TEST_ROOT/err_root" \
    || fail "root error unclear: $(cat "$TEST_ROOT/err_root")"
[[ "$(call_count)" -eq 0 ]] || fail "rsync ran for filesystem root"

# --- Negative: empty remote basename fail-closed (mock basename) ---
declare -r EMPTY_BASE_DIR="$TEST_ROOT/empty-base-dir"
mkdir -p "$EMPTY_BASE_DIR"
reset_calls
if "$TEMP_BACKUP" "$EMPTY_BASE_DIR" 2>"$TEST_ROOT/err_empty"; then
    fail "empty basename source succeeded"
fi
grep -qi 'refused remote basename' "$TEST_ROOT/err_empty" \
    || fail "empty basename error unclear: $(cat "$TEST_ROOT/err_empty")"
[[ "$(call_count)" -eq 0 ]] \
    || fail "rsync ran with empty remote basename (wipe risk)"

# --- Negative: errexit — failed rsync stops further syncs ---
declare -r ERR1="$TEST_ROOT/errexit-a"
declare -r ERR2="$TEST_ROOT/errexit-b"
mkdir -p "$ERR1" "$ERR2"
reset_calls
export RSYNC_FAIL_ON=0
if "$TEMP_BACKUP" "$ERR1" "$ERR2" 2>"$TEST_ROOT/err_rsync"; then
    fail "expected failure when mock rsync exits non-zero"
fi
[[ "$(call_count)" -eq 1 ]] \
    || fail "errexit broken: expected 1 rsync call, got $(call_count)"

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
declare -i i
for ((i = 0; i < ${#buggy_argv[@]}; i++)); do
    if [[ "${buggy_argv[i]}" == "$TEST_ROOT/split" ]]; then
        saw_split=1
    fi
done
((saw_split == 1)) || fail "buggy repro did not word-split as expected"

printf 'temp-backup test: ok\n'
