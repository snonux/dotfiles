#!/usr/bin/env bash
# Negative/repro checks for scripts/quicklog-drain JSON ack escaping (k33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r QUICKLOG_DRAIN="${SCRIPT_DIR}/../quicklog-drain"

fail() {
    printf 'quicklog-drain test: %s\n' "$*" >&2
    exit 1
}

bash -n "$QUICKLOG_DRAIN" || fail "bash -n failed"
shellcheck -x "$QUICKLOG_DRAIN" || fail "shellcheck failed"

# --- Structural: helper + call-site wiring (resilient, not brittle printf greps) ---

grep -q '^_emit_ack()' "$QUICKLOG_DRAIN" || fail "missing _emit_ack helper"

helper_fn=$(awk '/^_emit_ack\(\)/,/^}/' "$QUICKLOG_DRAIN")
[[ -n "$helper_fn" ]] || fail "could not extract _emit_ack"
grep -q -- '--arg key' <<<"$helper_fn" || fail "_emit_ack missing jq --arg key"
grep -q -- '--argjson ok' <<<"$helper_fn" \
    || fail "_emit_ack missing jq --argjson ok (ok must be JSON boolean)"

import_fn=$(awk '/^import_notes\(\)/,/^}/' "$QUICKLOG_DRAIN")
[[ -n "$import_fn" ]] || fail "could not extract import_notes"

# All three protocol ack paths must go through _emit_ack (empty / true / false).
emit_count=$(grep -cE '^[[:space:]]*_emit_ack ' <<<"$import_fn" || true)
[[ "$emit_count" -eq 3 ]] \
    || fail "import_notes expected 3 _emit_ack calls, got $emit_count"

grep -qE '_emit_ack[[:space:]]+""[[:space:]]+false[[:space:]]+>&' <<<"$import_fn" \
    || fail "missing empty-key _emit_ack false path to Dart FD"
# shellcheck disable=SC2016 # match literal $key in source, not expand it
grep -qE '_emit_ack[[:space:]]+"\$key"[[:space:]]+true[[:space:]]+>&' <<<"$import_fn" \
    || fail "missing success _emit_ack true path to Dart FD"
# shellcheck disable=SC2016 # match literal $key in source, not expand it
grep -qE '_emit_ack[[:space:]]+"\$key"[[:space:]]+false[[:space:]]+>&' <<<"$import_fn" \
    || fail "missing failure _emit_ack false path to Dart FD"

# Alternate broken emits inside import_notes must not appear.
if grep -nE 'printf[[:space:]]+.*\{.*"key"' <<<"$import_fn"; then
    fail "import_notes still builds ack JSON via printf"
fi
if grep -nE 'jq[[:space:]]+[^|]*\{key:' <<<"$import_fn"; then
    fail "import_notes builds ack via inline jq (must use _emit_ack)"
fi

# --- Load _emit_ack without sourcing the whole script (no fish/PATH deps) ---
# shellcheck disable=SC1090
eval "$helper_fn"
[[ "$(type -t _emit_ack)" == function ]] || fail "_emit_ack not defined after extract"

# Full-script source must also succeed when fish is absent from PATH.
bash_bin=$(command -v bash)
declare -r bash_bin
no_fish_bin=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf $(printf '%q' "$no_fish_bin")" EXIT
# shellcheck disable=SC2016 # $1 / command substitutions expand inside the child
PATH="$no_fish_bin" "$bash_bin" -c '
    set -euo pipefail
    # shellcheck source=scripts/quicklog-drain
    source "$1"
    [[ "$(type -t _emit_ack)" == function ]]
    [[ -z "${FISH_BIN:-}" ]]
' bash "$QUICKLOG_DRAIN" \
    || fail "sourcing quicklog-drain aborted without fish on PATH"

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

printf 'quicklog-drain test: ok\n'
