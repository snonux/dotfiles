#!/usr/bin/env bash
# Negative/repro checks for scripts/immich-upload JSON + curl -F path safety (f33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r IMMICH_UPLOAD="${SCRIPT_DIR}/../immich-upload"
declare -r IMMICH_LIB="${SCRIPT_DIR}/../lib/immich.sh"
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
bash -n "$IMMICH_LIB" || fail "bash -n failed on lib/immich.sh"
shellcheck -x "$IMMICH_UPLOAD" || fail "shellcheck failed"
shellcheck -x "$IMMICH_LIB" || fail "shellcheck failed on lib/immich.sh"

grep -Eq '^[[:space:]]*source[[:space:]].*lib/immich\.sh' "$IMMICH_UPLOAD" \
    || fail "immich-upload must source lib/immich.sh"
grep -q 'detect_immich_url' "$IMMICH_UPLOAD" \
    || fail "upload must call detect_immich_url"
grep -q '_account_api_key' "$IMMICH_UPLOAD" \
    || fail "upload must load key via _account_api_key"
# r33/q33 resilience: timeouts live in lib; upload must call curl_immich
# with -f + the shared timeout constants (parity with export guards).
grep -q 'CURL_PING_TIMEOUT' "$IMMICH_LIB" \
    || fail "missing CURL_PING_TIMEOUT in lib"
grep -q 'CURL_SEARCH_TIMEOUT' "$IMMICH_LIB" \
    || fail "missing CURL_SEARCH_TIMEOUT in lib"
grep -q 'CURL_DOWNLOAD_TIMEOUT' "$IMMICH_LIB" \
    || fail "missing CURL_DOWNLOAD_TIMEOUT in lib"
# shellcheck disable=SC2016  # intentional literal $CURL_* in grep
grep -Eq 'curl_immich -f "\$CURL_SEARCH_TIMEOUT"' "$IMMICH_UPLOAD" \
    || fail "bulk-check missing curl_immich -f CURL_SEARCH_TIMEOUT"
# Asset upload inspects HTTP status (200/201), so -f is not used there;
# still require the shared download timeout via curl_immich.
# shellcheck disable=SC2016
grep -Eq 'curl_immich "\$CURL_DOWNLOAD_TIMEOUT"' "$IMMICH_UPLOAD" \
    || fail "asset upload missing curl_immich CURL_DOWNLOAD_TIMEOUT"

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
grep -q '_assert_safe_path' "$IMMICH_UPLOAD" \
    || fail "missing _assert_safe_path helper"
# shellcheck disable=SC2016 # match literal $filename in source
grep -Fq -- '--form-string "filename=$filename"' "$IMMICH_UPLOAD" \
    || fail "missing --form-string filename= alongside assetData"

# Source helpers (main is gated on BASH_SOURCE).
# shellcheck source=scripts/immich-upload
source "$IMMICH_UPLOAD"

# Fixture paths with spaces, quotes, backslash, comma, semicolon.
declare -r EVIL_DIR="$TEST_ROOT/dir with spaces"
mkdir -p "$EVIL_DIR"
declare -r EVIL_PATH="$EVIL_DIR/photo \"quote\",semi;backslash\\name.jpg"
printf 'payload-bytes-for-f33\n' >"$EVIL_PATH"
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

# --- curl -F: quoted form keeps comma/semicolon; unescape must equal EVIL_PATH ---
form=$(_curl_form_file_field assetData "$EVIL_PATH" "$(basename "$EVIL_PATH")")
python3 -c '
import sys

form = sys.argv[1]
want = sys.argv[2]
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
escaped = rest[:i]
if "," not in escaped and ";" not in escaped:
    raise SystemExit("comma/semicolon not inside quoted path: " + escaped)
# Round-trip: unescape \\ and \" (order matters: process escapes left-to-right).
out = []
j = 0
while j < len(escaped):
    if escaped[j] == "\\" and j + 1 < len(escaped):
        out.append(escaped[j + 1])
        j += 2
        continue
    out.append(escaped[j])
    j += 1
got = "".join(out)
if got != want:
    raise SystemExit(
        "path round-trip mismatch:\n  got=%r\n want=%r\nescaped=%r"
        % (got, want, escaped)
    )
# Quote-only escaping (no backslash doubling) must fail this oracle:
# EVIL_PATH contains a real backslash, so escaped form must contain \\.
if "\\" in want and "\\\\" not in escaped:
    raise SystemExit("backslash not escaped in form path: " + escaped)
tail = rest[i + 1 :]
if not tail.startswith(";filename=\""):
    raise SystemExit("missing filename= segment: " + tail)
' "$form" "$EVIL_PATH" || fail "curl form path quoting/unescape failed"

# --- Behavioral: real curl -F opens/uploads the intended EVIL_PATH ---
upload_marker="$TEST_ROOT/uploaded.bin"
server_py="$TEST_ROOT/mock_upload_server.py"
port_file="$TEST_ROOT/mock_port"
cat >"$server_py" <<'PY'
import http.server
import re
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
port_path = Path(sys.argv[2])


def _extract_asset_data(body: bytes, content_type: str) -> bytes | None:
    match = re.search(rb"boundary=([^\s;]+)", content_type.encode())
    if not match:
        return None
    boundary = match.group(1).strip(b'"')
    marker = b"--" + boundary
    for part in body.split(marker):
        if b"name=\"assetData\"" not in part and b"name=assetData" not in part:
            continue
        # Headers end at blank line; body may end with trailing CRLF.
        split_at = part.find(b"\r\n\r\n")
        if split_at < 0:
            continue
        data = part[split_at + 4 :]
        if data.endswith(b"\r\n"):
            data = data[:-2]
        if data.endswith(b"--"):
            data = data[:-2]
            if data.endswith(b"\r\n"):
                data = data[:-2]
        return data
    return None


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        ctype = self.headers.get("Content-Type", "")
        data = _extract_asset_data(body, ctype)
        if data is None:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"missing assetData")
            return
        out_path.write_bytes(data)
        self.send_response(201)
        self.end_headers()
        self.wfile.write(b'{"status":"created"}')

    def log_message(self, fmt, *args):
        return


httpd = http.server.HTTPServer(("127.0.0.1", 0), Handler)
port_path.write_text(str(httpd.server_address[1]), encoding="utf-8")
httpd.handle_request()
PY
python3 "$server_py" "$upload_marker" "$port_file" &
server_pid=$!
# Wait briefly for the port file.
for _ in $(seq 1 50); do
    [[ -s "$port_file" ]] && break
    sleep 0.05
done
[[ -s "$port_file" ]] || fail "mock upload server did not publish port"
mock_port=$(<"$port_file")
curl -s -o /dev/null -w '%{http_code}' -X POST \
    -F "$form" \
    --form-string "filename=$(basename "$EVIL_PATH")" \
    "http://127.0.0.1:${mock_port}/api/assets" \
    | grep -qx '201' || fail "mock curl -F upload did not return 201"
wait "$server_pid" || fail "mock upload server exited uncleanly"
[[ -f "$upload_marker" ]] || fail "mock server wrote no upload body"
cmp -s "$EVIL_PATH" "$upload_marker" \
    || fail "curl -F did not upload bytes from EVIL_PATH"

# --- Negative: newline/tab in path rejected before TSV / bulk-check ---
# die() exits the shell; run assertions in a subshell.
if ( _assert_safe_path $'bad\tpath.jpg' ) 2>/dev/null; then
    fail "tab path was accepted by _assert_safe_path"
fi
if ( _assert_safe_path $'bad\npath.jpg' ) 2>/dev/null; then
    fail "newline path was accepted by _assert_safe_path"
fi
if printf '%s\t%s\n' "$EVIL_CHECKSUM" $'bad\tpath.jpg' \
    | _build_bulk_check_json >/dev/null 2>&1; then
    fail "TSV path with embedded tab was accepted by _build_bulk_check_json"
fi

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

# --- Negative: non-object result entry must fail loud ---
resp_entry="$TEST_ROOT/resp_entry.json"
printf '%s\n' '{"results":["not-an-object"]}' >"$resp_entry"
if _duplicate_ids_from_response "$resp_entry" >/dev/null 2>&1; then
    fail "non-object result entry was accepted"
fi

# --- Negative: duplicate entry missing id must fail loud ---
resp_noid="$TEST_ROOT/resp_noid.json"
printf '%s\n' \
    '{"results":[{"action":"reject","reason":"duplicate"}]}' >"$resp_noid"
if _duplicate_ids_from_response "$resp_noid" >/dev/null 2>&1; then
    fail "duplicate result missing id was accepted"
fi

printf 'immich-upload test: ok\n'
