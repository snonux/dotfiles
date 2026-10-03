#!/usr/bin/env bash
# Negative/repro checks for scripts/immich-upload JSON + curl -F path safety (f33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r IMMICH_UPLOAD="${SCRIPT_DIR}/../immich-upload"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'immich-upload test: %s\n' "$*" >&2
    exit 1
}

bash -n "$IMMICH_UPLOAD" || fail "bash -n failed"
shellcheck -x "$IMMICH_UPLOAD" || fail "shellcheck failed"

# Structural guards: no raw printf JSON, no embedded resp path, no swallowed parse.
# shellcheck disable=SC2016
if grep -Fq 'printf '\''{"id":"%s","checksum":"%s"}'\' "$IMMICH_UPLOAD"; then
    fail "pre-fix printf JSON embedding still present"
fi
if grep -Eq "open\('\\\$resp_file'\)" "$IMMICH_UPLOAD"; then
    fail "Python still embeds \$resp_file into source"
fi
if grep -Eq 'except Exception:[[:space:]]*$' "$IMMICH_UPLOAD"; then
    fail "silent except Exception: still present"
fi
# shellcheck disable=SC2016
if grep -Fq 'assetData=@$file' "$IMMICH_UPLOAD"; then
    fail "pre-fix unquoted curl -F assetData=@\$file still present"
fi
grep -q '_build_bulk_check_json' "$IMMICH_UPLOAD" \
    || fail "missing _build_bulk_check_json helper"
grep -q '_curl_form_file_field' "$IMMICH_UPLOAD" \
    || fail "missing _curl_form_file_field helper"
grep -q '_duplicate_ids_from_response' "$IMMICH_UPLOAD" \
    || fail "missing _duplicate_ids_from_response helper"

# Source helpers (main is gated on BASH_SOURCE).
# shellcheck source=scripts/immich-upload
source "$IMMICH_UPLOAD"

# Fixture paths with spaces, quotes, backslash, comma, semicolon.
declare -r EVIL_DIR="$TEST_ROOT/dir with spaces"
mkdir -p "$EVIL_DIR"
declare -r EVIL_PATH="$EVIL_DIR/photo \"quote\",semi;backslash\\name.jpg"
: >"$EVIL_PATH"
declare -r EVIL_CHECKSUM='deadbeefdeadbeefdeadbeefdeadbeefdeadbeef'

# --- Negative repro: raw printf into JSON breaks on quotes/backslashes ---
buggy_json=$(
    # shellcheck disable=SC2059 # intentional buggy repro of the old printf form
    printf '{"assets":[{"id":"%s","checksum":"%s"}]}' \
        "$EVIL_PATH" "$EVIL_CHECKSUM"
)
if printf '%s' "$buggy_json" | python3 -c 'import json,sys; json.load(sys.stdin)' \
    2>/dev/null; then
    fail "buggy printf repro unexpectedly produced valid JSON"
fi

# --- Fixed: json.dumps encodes arbitrary paths ---
fixed_json=$(
    printf '%s\t%s\n' "$EVIL_CHECKSUM" "$EVIL_PATH" | _build_bulk_check_json
)
printf '%s' "$fixed_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["assets"][0]["id"] == sys.argv[1], data
assert data["assets"][0]["checksum"] == sys.argv[2], data
' "$EVIL_PATH" "$EVIL_CHECKSUM" \
    || fail "fixed bulk-check JSON failed round-trip for special path"

# jq --arg alternative also encodes safely (documents expected approach).
if command -v jq >/dev/null 2>&1; then
    jq_json=$(
        jq -n --arg id "$EVIL_PATH" --arg checksum "$EVIL_CHECKSUM" \
            '{assets:[{id:$id, checksum:$checksum}]}'
    )
    printf '%s' "$jq_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
assert data["assets"][0]["id"] == sys.argv[1]
' "$EVIL_PATH" || fail "jq --arg JSON round-trip failed"
fi

# --- curl -F: quoted form keeps comma/semicolon inside the path ---
form=$(_curl_form_file_field assetData "$EVIL_PATH" "$(basename "$EVIL_PATH")")
python3 -c '
import sys
form = sys.argv[1]
# After assetData=@"...", the first unescaped " closes the path.
if not form.startswith("assetData=@\""):
    raise SystemExit("missing quoted @path: " + form)
rest = form[len("assetData=@\""):]
i = 0
while i < len(rest):
    if rest[i] == "\\" and i + 1 < len(rest):
        i += 2
        continue
    if rest[i] == "\"":
        break
    i += 1
else:
    raise SystemExit("no closing quote for path: " + form)
path = rest[:i]
if "," not in path and ";" not in path:
    raise SystemExit("comma/semicolon not inside quoted path: " + path)
tail = rest[i + 1 :]
if not tail.startswith(";filename=\""):
    raise SystemExit("missing filename= segment: " + tail)
' "$form" || fail "curl form path quoting failed for comma/semicolon path"

# --- Duplicate parse: valid response ---
resp_ok="$TEST_ROOT/resp_ok.json"
python3 -c '
import json, sys
json.dump({
    "results": [
        {"id": sys.argv[1], "action": "reject", "reason": "duplicate"},
        {"id": "other.jpg", "action": "accept"},
    ]
}, open(sys.argv[2], "w"))
' "$EVIL_PATH" "$resp_ok"
got=$(_duplicate_ids_from_response "$resp_ok") \
    || fail "valid duplicate parse failed"
[[ "$got" == "$EVIL_PATH" ]] || fail "duplicate id=${got@Q}, want evil path"

# --- Negative: invalid JSON must fail loud (not silent pass) ---
resp_bad="$TEST_ROOT/resp_bad.json"
printf 'not-json{' >"$resp_bad"
if _duplicate_ids_from_response "$resp_bad" >/dev/null 2>&1; then
    fail "invalid JSON was accepted (should fail loud)"
fi

# --- Negative: missing results must fail loud ---
resp_miss="$TEST_ROOT/resp_miss.json"
printf '%s\n' '{"status":"ok"}' >"$resp_miss"
if _duplicate_ids_from_response "$resp_miss" >/dev/null 2>&1; then
    fail "response missing results was accepted"
fi

# --- Negative: results not a list must fail loud ---
resp_obj="$TEST_ROOT/resp_obj.json"
printf '%s\n' '{"results":{"id":"x"}}' >"$resp_obj"
if _duplicate_ids_from_response "$resp_obj" >/dev/null 2>&1; then
    fail "non-list results was accepted"
fi

printf 'immich-upload test: ok\n'
