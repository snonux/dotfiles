#!/usr/bin/env bash
# Checks for scripts/sideload-koreader APK path quoting (task l33).
#
# Quoting on [[ -f "$APK" ]] is required hygiene (ShellCheck SC2086, consistent
# path handling, and prevention of future [ -f $APK ] misuse). Bash [[ does not
# word-split or pathname-expand the unquoted operand the way [ does, so this
# suite does not claim a bash [[ word-split failure for spaced paths.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r SIDELOAD="${SCRIPT_DIR}/../sideload-koreader"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'sideload-koreader test: %s\n' "$*" >&2
    exit 1
}

mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/calls"

# Mock adb: record each invocation; implement the tiny subset sideload needs.
cat >"$TEST_ROOT/bin/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${ADB_CALL_DIR:?ADB_CALL_DIR unset}"
declare -i n
n=$(find "$ADB_CALL_DIR" -maxdepth 1 -type f -name 'call.*' | wc -l)
declare -r out="$ADB_CALL_DIR/call.${n}"
printf '%s\0' "$@" >"$out"

case "${1:-}" in
    get-state)
        printf 'device\n'
        ;;
    push)
        ;;
    shell)
        shift
        case "${1:-}" in
            getprop)
                printf 'Supernote A6 X2\n'
                ;;
            rm)
                ;;
            pm)
                shift
                case "${1:-}" in
                    install) ;;
                    list)
                        printf 'package:org.koreader.launcher\n'
                        ;;
                    *)
                        printf 'adb mock: unknown pm subcommand: %s\n' "$*" >&2
                        exit 1
                        ;;
                esac
                ;;
            *)
                printf 'adb mock: unknown shell command: %s\n' "$*" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        printf 'adb mock: unknown command: %s\n' "$*" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/adb"

export PATH="$TEST_ROOT/bin:$PATH"
export ADB_CALL_DIR="$TEST_ROOT/calls"

reset_calls() {
    rm -f "$ADB_CALL_DIR"/call.*
}

push_argv() {
    local -n _out="$1"
    local f
    for f in "$ADB_CALL_DIR"/call.*; do
        [[ -f "$f" ]] || continue
        mapfile -d '' -t _out <"$f"
        if ((${#_out[@]} >= 1)) && [[ "${_out[0]}" == push ]]; then
            return 0
        fi
    done
    fail "no adb push call recorded"
}

bash -n "$SIDELOAD" || fail "bash -n failed"
shellcheck -x "$SIDELOAD" || fail "shellcheck failed"

# Structural guards: APK assignment and -f check must quote the path.
# shellcheck disable=SC2016
grep -Fq 'declare -r APK="$1"' "$SIDELOAD" \
    || fail 'missing quoted declare -r APK="$1"'
# shellcheck disable=SC2016
grep -Fq '[[ -f "$APK" ]]' "$SIDELOAD" \
    || fail 'missing quoted [[ -f "$APK" ]] check'
# shellcheck disable=SC2016
if grep -Eq '\[\[ -f \$APK \]\]' "$SIDELOAD"; then
    fail 'pre-fix unquoted [[ -f $APK ]] still present'
fi
# shellcheck disable=SC2016
if grep -Eq 'declare -r APK=\$1' "$SIDELOAD"; then
    fail 'pre-fix unquoted declare -r APK=$1 still present'
fi

declare -r SPACE_APK="$TEST_ROOT/dir with spaces/KOReader release.apk"
mkdir -p "$(dirname "$SPACE_APK")"
: >"$SPACE_APK"

# --- Negative: missing APK fail-closed ---
reset_calls
set +e
missing_err="$("$SIDELOAD" "$TEST_ROOT/no such file.apk" 2>&1)"
missing_rc=$?
set -e
((missing_rc != 0)) || fail "expected failure for missing APK"
[[ "$missing_err" == *'APK not found'* ]] \
    || fail "missing APK message unexpected: ${missing_err@Q}"

# --- Negative: wrong argc ---
set +e
usage_err="$("$SIDELOAD" 2>&1)"
usage_rc=$?
set -e
((usage_rc == 2)) || fail "expected exit 2 for missing argc, got $usage_rc"
[[ "$usage_err" == *Usage:* ]] || fail "usage text missing: ${usage_err@Q}"

# --- Positive: path with spaces survives -f and reaches adb push intact ---
reset_calls
"$SIDELOAD" "$SPACE_APK" >/dev/null \
    || fail "sideload failed for APK path with spaces"
declare -a push_args=()
push_argv push_args
[[ "${push_args[1]}" == "$SPACE_APK" ]] \
    || fail "adb push path mangled: got ${push_args[1]@Q}"

# --- Positive: literal filename containing a glob metacharacter ---
declare -r STAR_APK="$TEST_ROOT/koreader v*.apk"
: >"$STAR_APK"
reset_calls
"$SIDELOAD" "$STAR_APK" >/dev/null \
    || fail "sideload failed for APK path with glob metachar"
push_argv push_args
[[ "${push_args[1]}" == "$STAR_APK" ]] \
    || fail "adb push glob path mangled: got ${push_args[1]@Q}"

printf 'sideload-koreader test: ok\n'
