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
# ack it reads back to acks.log; it then exits with the number in
# stream-rc if present, else 0. The fake fish fails the import when the
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
[[ -f stream-rc ]] && exit "$(cat stream-rc)"
exit 0
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

# --- 0h4: the coprocess exits and is reaped while the loop still runs ---
# The fake dart exits as soon as it has read its last ack. A slow jq (the
# real one, then a pause before exiting) keeps the drain inside _emit_ack
# after dart already has the ack, so bash reaps dart and unsets DARTPROC
# before the loop's next read. The drain must still read EOF, report the
# import and exit 0; before the fix it died with "DARTPROC[0]: unbound
# variable" on every run. The slow jq is on PATH for this run only.
real_jq=$(command -v jq)
declare -r SLOW_BIN="$TEST_ROOT/slow-bin"
mkdir -p "$SLOW_BIN"
# shellcheck disable=SC2016 # $@ and $rc expand in the generated script
printf '#!/usr/bin/env bash\n"%s" "$@"\nrc=$?\nsleep 0.3\nexit "$rc"\n' \
    "$real_jq" >"$SLOW_BIN/jq"
chmod +x "$SLOW_BIN/jq"
cp "$QL_REPO/stream.jsonl" "$QL_REPO/stream.jsonl.all"
jq -nc '{key:"ql-ok.md",content:"buy bread"}' >"$QL_REPO/stream.jsonl"

# run_reaped — run the drain with the slow jq; sets reaped_rc.
run_reaped() {
    : >"$QL_REPO/acks.log"
    reaped_rc=0
    env -u PROGRAM \
        HOME="$QL_HOME" PATH="$SLOW_BIN:$QL_BIN:$PATH" \
        XDG_RUNTIME_DIR="$TEST_ROOT/run" \
        QUICKLOG_CREDS="$TEST_ROOT/creds.env" QUICKLOG_REPO="$QL_REPO" \
        QUICKLOG_DART="$QL_BIN/dart" QUICKLOG_FISH_CONF_DIR="$QL_CONF" \
        "$QUICKLOG_DRAIN" >"$TEST_ROOT/drain.out" 2>"$TEST_ROOT/drain.err" \
        || reaped_rc=$?
}

run_reaped
[[ "$reaped_rc" -eq 0 ]] \
    || fail "0h4: drain exited $reaped_rc after the coprocess was reaped: $(cat "$TEST_ROOT/drain.err")"
grep -Fxq 'quicklog-drain: imported=1 kept=0 dart_rc=0' "$TEST_ROOT/drain.out" \
    || fail "0h4: summary missing or wrong: $(cat "$TEST_ROOT/drain.out")"
mapfile -t acks <"$QL_REPO/acks.log"
[[ "${#acks[@]}" -eq 1 ]] \
    || fail "0h4: want 1 ack, got ${#acks[@]}: $(cat "$QL_REPO/acks.log")"
assert_ack 'ql-ok.md' true "${acks[0]}"
# Negative: a Dart that fails after its last ack, and is reaped before the
# loop ends, still fails the drain with its own status in the summary.
printf '5\n' >"$QL_REPO/stream-rc"
run_reaped
[[ "$reaped_rc" -eq 1 ]] \
    || fail "0h4: want rc 1 for a failed dart, got $reaped_rc: $(cat "$TEST_ROOT/drain.err")"
grep -Fxq 'quicklog-drain: imported=1 kept=0 dart_rc=5' "$TEST_ROOT/drain.out" \
    || fail "0h4: failed dart summary wrong: $(cat "$TEST_ROOT/drain.out")"
rm -f "$QL_REPO/stream-rc"
mv "$QL_REPO/stream.jsonl.all" "$QL_REPO/stream.jsonl"

# --- pg4: main's options and modes, pinned before main was split ---
# A second fake dart logs every call (pub get included) to args.log in the
# repo, streams nothing, and exits with the number in dart-rc if present.
cat >"$QL_BIN/dart-args" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>args.log
[[ -f dart-rc ]] && exit "$(cat dart-rc)"
exit 0
EOF
chmod +x "$QL_BIN/dart-args"

# run_args ARGS... — run the drain with dart-args; sets args_rc and leaves
# the dart calls in args.log, stdout in drain.out, stderr in drain.err.
run_args() {
    : >"$QL_REPO/args.log"
    args_rc=0
    env -u PROGRAM \
        HOME="$QL_HOME" PATH="$QL_BIN:$PATH" \
        XDG_RUNTIME_DIR="$TEST_ROOT/run" \
        QUICKLOG_CREDS="$TEST_ROOT/creds.env" QUICKLOG_REPO="$QL_REPO" \
        QUICKLOG_DART="$QL_BIN/dart-args" QUICKLOG_FISH_CONF_DIR="$QL_CONF" \
        "$QUICKLOG_DRAIN" "$@" \
        </dev/null >"$TEST_ROOT/drain.out" 2>"$TEST_ROOT/drain.err" \
        || args_rc=$?
}

# expect_args WANT_RC WANT_DART_CALLS ARGS... — run_args, then compare the
# exit status and the exact dart call log (one call per line).
expect_args() {
    local -r want_rc="$1" want_calls="$2"
    shift 2
    run_args "$@"
    [[ "$args_rc" -eq "$want_rc" ]] \
        || fail "pg4 '$*': want rc $want_rc, got $args_rc: $(cat "$TEST_ROOT/drain.err")"
    [[ "$(cat "$QL_REPO/args.log")" == "$want_calls" ]] \
        || fail "pg4 '$*': dart calls changed: $(cat "$QL_REPO/args.log")"
}

declare -r D='run bin/quicklog_drain.dart'
expect_args 0 "$D --dest /x --dry-run --force --limit 2 --only a,b" \
    --dest /x --dry-run --force --limit 2 --only a,b
expect_args 0 "$D --dest /y --limit 3 --only k" --dest=/y --limit=3 --only=k
expect_args 0 "$D --dest /z" --dest /z
expect_args 0 "$D --import --dry-run --limit 2 --only k" --dry-run --limit 2 --only k
expect_args 0 "$D --import --dry-run" --dry-run
expect_args 0 "pub get
$D --import --limit 5 --only k" --limit 5 --only k
grep -Fxq 'quicklog-drain: imported=0 kept=0 dart_rc=0' "$TEST_ROOT/drain.out" \
    || fail "pg4: empty import summary changed: $(cat "$TEST_ROOT/drain.out")"

# The dart status is the script's status in every mode; a failed pub get is
# ignored (the fake fails it too, as dart-rc applies to every call).
printf '7\n' >"$QL_REPO/dart-rc"
expect_args 7 "$D --dest /x" --dest /x
expect_args 7 "$D --import --dry-run" --dry-run
expect_args 1 "pub get
$D --import"
grep -Fxq 'quicklog-drain: imported=0 kept=0 dart_rc=7' "$TEST_ROOT/drain.out" \
    || fail "pg4: failed import summary changed: $(cat "$TEST_ROOT/drain.out")"
rm -f "$QL_REPO/dart-rc"

# Usage errors exit 64 before any dart call; --help exits 0. Both print the
# usage text to stderr.
for bad in '--dest' '--limit' '--limit 0' '--limit x' '--limit=0' '--limit=' \
    '--only' '--only=' '--bogus'; do
    # shellcheck disable=SC2086 # split the option string on purpose
    expect_args 64 '' $bad
    grep -Fq 'Usage: quicklog-drain [--dry-run]' "$TEST_ROOT/drain.err" \
        || fail "pg4 '$bad': no usage on stderr: $(cat "$TEST_ROOT/drain.err")"
done
expect_args 64 '' --only ''
expect_args 0 '' --help
grep -Fq 'Usage: quicklog-drain [--dry-run]' "$TEST_ROOT/drain.err" \
    || fail "pg4 --help: no usage on stderr"
expect_args 64 '' --force
[[ "$(cat "$TEST_ROOT/drain.err")" == 'quicklog-drain: --force only applies with --dest' ]] \
    || fail "pg4 --force: message changed: $(cat "$TEST_ROOT/drain.err")"

# Missing credentials stop the run (set -e) before any dart call.
mv "$TEST_ROOT/creds.env" "$TEST_ROOT/creds.env.off"
expect_args 1 '' --dry-run
grep -Fxq "quicklog-drain: missing $TEST_ROOT/creds.env" "$TEST_ROOT/drain.err" \
    || fail "pg4: missing-creds message changed: $(cat "$TEST_ROOT/drain.err")"
mv "$TEST_ROOT/creds.env.off" "$TEST_ROOT/creds.env"

# Import modes report notes stranded by the retired staging flow; --dest
# does not.
mkdir -p "$QL_HOME/Notes/Quicklog"
: >"$QL_HOME/Notes/Quicklog/ql-old.md"
expect_args 0 "$D --import --dry-run" --dry-run
grep -Fq "quicklog-drain: found 1 stranded note(s) in $QL_HOME/Notes/Quicklog" \
    "$TEST_ROOT/drain.err" \
    || fail "pg4: stranded notes not reported: $(cat "$TEST_ROOT/drain.err")"
expect_args 0 "$D --dest /x" --dest /x
[[ ! -s "$TEST_ROOT/drain.err" ]] \
    || fail "pg4: --dest reported stranded notes: $(cat "$TEST_ROOT/drain.err")"
rm -rf "$QL_HOME/Notes"

printf 'quicklog-drain test: ok\n'
