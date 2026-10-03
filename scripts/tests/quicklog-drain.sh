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

# Structural guards: no raw printf into JSON ack strings.
# shellcheck disable=SC2016
if grep -Fq 'printf '\''{"key":"%s","ok":true}'\' "$QUICKLOG_DRAIN"; then
    fail "pre-fix printf ok:true ack still present"
fi
# shellcheck disable=SC2016
if grep -Fq 'printf '\''{"key":"%s","ok":false}'\' "$QUICKLOG_DRAIN"; then
    fail "pre-fix printf ok:false ack still present"
fi
# shellcheck disable=SC2016
if grep -Fq 'printf '\''{"key":"","ok":false}'\' "$QUICKLOG_DRAIN"; then
    fail "pre-fix printf empty-key ack still present"
fi
grep -q '_emit_ack' "$QUICKLOG_DRAIN" || fail "missing _emit_ack helper"

# Source helpers only (main is gated on BASH_SOURCE).
# shellcheck source=scripts/quicklog-drain
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
    local got_key got_ok
    printf '%s' "$line" | jq -e . >/dev/null \
        || fail "ack is not valid JSON: ${line@Q}"
    # Protocol is JSON-lines: compact output must not embed raw newlines
    # (command substitution already strips a trailing newline from jq).
    [[ "$line" != *$'\n'* ]] \
        || fail "ack embeds a raw newline: ${line@Q}"
    got_key=$(jq -r '.key' <<<"$line")
    got_ok=$(jq -r '.ok' <<<"$line")
    [[ "$got_key" == "$want_key" ]] \
        || fail "ack key=${got_key@Q}, want ${want_key@Q}"
    [[ "$got_ok" == "$want_ok" ]] \
        || fail "ack ok=${got_ok@Q}, want ${want_ok@Q}"
}

# --- Fixed: jq --arg encodes arbitrary keys ---
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
