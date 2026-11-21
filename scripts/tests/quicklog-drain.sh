#!/usr/bin/env bash
# Checks for scripts/quicklog/drain JSON ack escaping (k33) and its wrapper.
# Nothing greps the scripts: _emit_ack is called directly, and the import
# loop runs through the wrapper with a fake dart (protocol stream) and a
# fake fish (import result), so the acks it writes are checked as data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r QUICKLOG_DRAIN="${SCRIPT_DIR}/../quicklog/drain"
declare -r QUICKLOG_DRAIN_WRAPPER="${SCRIPT_DIR}/../quicklog-drain"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'quicklog-drain test: %s\n' "$*" >&2
    exit 1
}

bash -n "$QUICKLOG_DRAIN" || fail "bash -n failed"
bash -n "$QUICKLOG_DRAIN_WRAPPER" || fail "bash -n wrapper failed"
[[ -x "$QUICKLOG_DRAIN_WRAPPER" ]] || fail "wrapper not executable"
shellcheck -x "$QUICKLOG_DRAIN" || fail "shellcheck failed"
shellcheck -x "$QUICKLOG_DRAIN_WRAPPER" || fail "shellcheck wrapper failed"

# Full-script source must succeed when fish is absent from PATH.
bash_bin=$(command -v bash)
declare -r bash_bin
no_fish_bin="$TEST_ROOT/no-fish-bin"
mkdir -p "$no_fish_bin"
# shellcheck disable=SC2016 # $1 / command substitutions expand inside the child
PATH="$no_fish_bin" "$bash_bin" -c '
    set -euo pipefail
    # shellcheck source=scripts/quicklog/drain
    source "$1"
    [[ "$(type -t _emit_ack)" == function ]]
    [[ -z "${FISH_BIN:-}" ]]
' bash "$QUICKLOG_DRAIN" \
    || fail "sourcing quicklog-drain aborted without fish on PATH"

# Load _emit_ack for the unit checks below by sourcing the script into this
# shell (main is gated on BASH_SOURCE, so nothing runs).
# shellcheck source=scripts/quicklog/drain
source "$QUICKLOG_DRAIN"

# --- Negative repro: printf into JSON string breaks on quotes/backslashes ---
declare -r EVIL_KEY='ql-"quote"\backslash.md'
buggy_json=$(
    # shellcheck disable=SC2059 # intentional buggy repro of the old printf form
    printf '{"key":"%s","ok":true}\n' "$EVIL_KEY"
)
if printf '%s' "$buggy_json" | jq -e . >/dev/null 2>&1; then
    fail "buggy printf repro unexpectedly produced valid JSON"
fi

# Newline in the key also breaks single-line protocol (and often JSON parse).
declare -r NL_KEY=$'ql-line1\nline2.md'
buggy_nl=$(
    # shellcheck disable=SC2059 # intentional buggy repro of the old printf form
    printf '{"key":"%s","ok":true}\n' "$NL_KEY"
)
if printf '%s' "$buggy_nl" | jq -e . >/dev/null 2>&1; then
    fail "buggy printf newline repro unexpectedly produced valid JSON"
fi

assert_ack() {
    local -r want_key="$1"
    local -r want_ok="$2"
    local -r line="$3"

    printf '%s' "$line" | jq -e . >/dev/null \
        || fail "ack is not valid JSON: ${line@Q}"
    # Protocol is JSON-lines: compact output must not embed raw newlines
    # (command substitution already strips a trailing newline from jq).
    [[ "$line" != *$'\n'* ]] \
        || fail "ack embeds a raw newline: ${line@Q}"

    # ok must be a JSON boolean (type==boolean), not the strings "true"/"false".
    jq -e --arg want_key "$want_key" --argjson want_ok "$want_ok" \
        '.key == $want_key and (.ok|type=="boolean") and .ok == $want_ok' \
        <<<"$line" >/dev/null \
        || fail "ack key/ok/type mismatch: ${line@Q} want key=${want_key@Q} ok=${want_ok}"
}

# Deliberate --arg ok true (string) must FAIL assert_ack.
string_ok_ack=$(
    jq -nc --arg key 'ql-plain.md' --arg ok true '{key:$key,ok:$ok}'
)
jq -e '.ok|type=="string"' <<<"$string_ok_ack" >/dev/null \
    || fail "setup: expected string-typed ok fixture"
if (assert_ack 'ql-plain.md' true "$string_ok_ack") 2>/dev/null; then
    fail "assert_ack accepted string ok (must require JSON boolean)"
fi

# --- Fixed: jq --arg encodes arbitrary keys; --argjson keeps ok boolean ---
ack=$(_emit_ack "$EVIL_KEY" true)
assert_ack "$EVIL_KEY" true "$ack"

ack=$(_emit_ack "$NL_KEY" false)
assert_ack "$NL_KEY" false "$ack"

ack=$(_emit_ack "" false)
assert_ack "" false "$ack"

ack=$(_emit_ack 'ql-plain.md' true)
assert_ack 'ql-plain.md' true "$ack"

# Unicode / spaces / tabs round-trip.
declare -r UNI_KEY=$'ql-ünïcode path\twith tab.md'
ack=$(_emit_ack "$UNI_KEY" true)
assert_ack "$UNI_KEY" true "$ack"

# --- Entry point: the import loop acks every stream line as JSON ---
# The wrapper runs with a throwaway HOME, credentials file, repo, lock dir
# and fish conf.d. The fake dart (run with env -i inside REPO, so it uses
# files there) writes each line of stream.jsonl to the drain and logs the
# ack it reads back to acks.log. The fake fish fails the import when the
# note content is FAIL. Nothing reaches Garage, Dart or taskwarrior.
declare -r QL_HOME="$TEST_ROOT/home"
declare -r QL_REPO="$TEST_ROOT/repo"
declare -r QL_CONF="$TEST_ROOT/conf.d"
declare -r QL_BIN="$TEST_ROOT/ql-bin"
mkdir -p "$QL_HOME" "$QL_REPO" "$QL_CONF" "$QL_BIN" "$TEST_ROOT/run"
: >"$QL_CONF/taskwarrior.fish"
: >"$QL_CONF/quicklog.fish"
printf '%s\n' \
    'GARAGE_ENDPOINT=http://garage.invalid' 'GARAGE_REGION=garage' \
    'GARAGE_BUCKET=quicklog' 'GARAGE_ACCESS_KEY_ID=fake-id' \
    'GARAGE_SECRET_ACCESS_KEY=fake-secret' >"$TEST_ROOT/creds.env"
cat >"$QL_BIN/dart" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == pub ]] && exit 0
printf '%s\n' "$*" >>args.log
while IFS= read -r -u 4 line; do
    printf '%s\n' "$line"
    IFS= read -r ack || exit 3
    printf '%s\n' "$ack" >>acks.log
done 4<stream.jsonl
EOF
cat >"$QL_BIN/fish" <<'EOF'
#!/usr/bin/env bash
content=$(cat)
[[ "$content" != FAIL ]]
EOF
chmod +x "$QL_BIN/dart" "$QL_BIN/fish"
# Keys: one with quotes and a backslash (imports), one whose import fails,
# then a line with no key (malformed; must get a mismatched false ack).
jq -nc --arg key "$EVIL_KEY" '{key:$key,content:"buy milk"}' >"$QL_REPO/stream.jsonl"
jq -nc '{key:"ql-fail.md",content:"FAIL"}' >>"$QL_REPO/stream.jsonl"
printf '%s\n' 'not a protocol line' >>"$QL_REPO/stream.jsonl"

# run_drain PROGRAM_OR_EMPTY TARGET — run TARGET (wrapper or drain) in the
# sandbox; PROGRAM is preset only when the first argument is not empty.
run_drain() {
    local -r program="$1" target="$2"
    local -a preset=()
    [[ -n "$program" ]] && preset=("PROGRAM=$program")
    : >"$QL_REPO/acks.log"
    env -u PROGRAM "${preset[@]}" \
        HOME="$QL_HOME" PATH="$QL_BIN:$PATH" \
        XDG_RUNTIME_DIR="$TEST_ROOT/run" \
        QUICKLOG_CREDS="$TEST_ROOT/creds.env" QUICKLOG_REPO="$QL_REPO" \
        QUICKLOG_DART="$QL_BIN/dart" QUICKLOG_FISH_CONF_DIR="$QL_CONF" \
        "$target" >"$TEST_ROOT/drain.out" 2>"$TEST_ROOT/drain.err"
}

if run_drain '' "$QUICKLOG_DRAIN_WRAPPER"; then
    fail "drain exited 0 although one import failed"
fi
grep -Fxq 'run bin/quicklog_drain.dart --import' "$QL_REPO/args.log" \
    || fail "wrapper did not reach the drain's import: $(cat "$QL_REPO/args.log")"
mapfile -t acks <"$QL_REPO/acks.log"
[[ "${#acks[@]}" -eq 3 ]] \
    || fail "want 3 acks, got ${#acks[@]}: $(cat "$QL_REPO/acks.log")"
assert_ack "$EVIL_KEY" true "${acks[0]}"
assert_ack 'ql-fail.md' false "${acks[1]}"
assert_ack '' false "${acks[2]}"
# The wrapper names the program quicklog-drain (not "drain").
grep -Fq 'quicklog-drain: imported=1 kept=1 dart_rc=0' "$TEST_ROOT/drain.out" \
    || fail "wrapper summary wrong: $(cat "$TEST_ROOT/drain.out")"
grep -Fq 'quicklog-drain: import failed for ql-fail.md' "$TEST_ROOT/drain.err" \
    || fail "wrapper error prefix wrong: $(cat "$TEST_ROOT/drain.err")"

# The drain keeps a preset PROGRAM (and the wrapper passes it through).
for target in "$QUICKLOG_DRAIN" "$QUICKLOG_DRAIN_WRAPPER"; do
    run_drain 'ql-custom' "$target" || true
    grep -Fq 'ql-custom: imported=1 kept=1' "$TEST_ROOT/drain.out" \
        || fail "preset PROGRAM ignored by ${target##*/}: $(cat "$TEST_ROOT/drain.out")"
done

printf 'quicklog-drain test: ok\n'
