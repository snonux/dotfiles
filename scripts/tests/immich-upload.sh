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

# Kept as a source check: which file supplies the shared helpers has no
# behaviour of its own (tests/immich-lib.sh pins the helpers themselves).
grep -Eq '^[[:space:]]*source[[:space:]].*lib/immich\.sh' "$IMMICH_UPLOAD" \
    || fail "immich-upload must source lib/immich.sh"

# Every other rule is checked by running the script below, not by grepping
# it: JSON building, form quoting and response parsing as units, then key
# loading, URL failover, timeouts, the multipart upload and exit status
# through the entry point with a fake curl (or a local mock server).

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

# --- Entry point: real curl uploads EVIL_PATH's bytes to a local mock ---
# immich-upload runs as a command: the key comes from $HOME/.immich_paul_key,
# detect_immich_url pings the LAN URL, and real curl builds the multipart
# POST from the quoted -F field and --form-string filename. The mock listens
# on 127.0.0.1 only; it answers the ping and records the assetData bytes,
# the filename field and the x-api-key header it received.
declare -r KEY_HOME="$TEST_ROOT/key-home"
mkdir -p "$KEY_HOME"
# Made-up key; distinctive so the leak greps cannot misfire.
declare -r FAKE_API_KEY='fake-immich-upload-key-2b8c'
printf '%s\n' "$FAKE_API_KEY" >"$KEY_HOME/.immich_paul_key"
mock_dir="$TEST_ROOT/mock"
mkdir -p "$mock_dir"
server_py="$TEST_ROOT/mock_upload_server.py"
cat >"$server_py" <<'PY'
import http.server
import re
import sys
import time
from pathlib import Path

out_dir = Path(sys.argv[1])
done = False


def _part(body: bytes, content_type: str, name: bytes) -> bytes | None:
    match = re.search(rb"boundary=([^\s;]+)", content_type.encode())
    if not match:
        return None
    marker = b"--" + match.group(1).strip(b'"')
    for part in body.split(marker):
        if b'name="' + name + b'"' not in part:
            continue
        split_at = part.find(b"\r\n\r\n")
        if split_at < 0:
            continue
        data = part[split_at + 4 :]
        return data[:-2] if data.endswith(b"\r\n") else data
    return None


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        code = 200 if self.path == "/api/server/ping" else 404
        self.send_response(code)
        self.end_headers()
        self.wfile.write(b'{"res":"pong"}')

    def do_POST(self):
        global done
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        ctype = self.headers.get("Content-Type", "")
        data = _part(body, ctype, b"assetData")
        filename = _part(body, ctype, b"filename")
        if self.path != "/api/assets" or data is None or filename is None:
            self.send_response(400)
            self.end_headers()
            return
        (out_dir / "assetData").write_bytes(data)
        (out_dir / "filename").write_bytes(filename)
        (out_dir / "api-key").write_text(self.headers.get("x-api-key", ""))
        done = True
        self.send_response(201)
        self.end_headers()
        self.wfile.write(b'{"status":"created"}')

    def log_message(self, fmt, *args):
        return


httpd = http.server.HTTPServer(("127.0.0.1", 0), Handler)
httpd.timeout = 1
(out_dir / "port").write_text(str(httpd.server_address[1]))
deadline = time.monotonic() + 30
while not done and time.monotonic() < deadline:
    httpd.handle_request()
PY
python3 "$server_py" "$mock_dir" &
server_pid=$!
for _ in $(seq 1 50); do
    [[ -s "$mock_dir/port" ]] && break
    sleep 0.05
done
[[ -s "$mock_dir/port" ]] || fail "mock upload server did not publish port"
mock_port=$(<"$mock_dir/port")
set +e
HOME="$KEY_HOME" NO_PROXY='127.0.0.1' no_proxy='127.0.0.1' \
IMMICH_LAN_URL="http://127.0.0.1:${mock_port}" \
IMMICH_PUBLIC_URL='http://127.0.0.1:9' \
"$IMMICH_UPLOAD" "$EVIL_PATH" >"$TEST_ROOT/mock.out" 2>"$TEST_ROOT/mock.err"
mock_rc=$?
set -e
wait "$server_pid" || fail "mock upload server exited uncleanly"
[[ "$mock_rc" -eq 0 ]] \
    || fail "entry point upload to mock failed (rc $mock_rc): $(cat "$TEST_ROOT/mock.err")"
grep -Fq 'Using LAN ingress' "$TEST_ROOT/mock.out" \
    || fail "entry point did not ping the LAN URL: $(cat "$TEST_ROOT/mock.out")"
[[ -f "$mock_dir/assetData" ]] || fail "mock server received no upload"
cmp -s "$EVIL_PATH" "$mock_dir/assetData" \
    || fail "upload did not carry the bytes of EVIL_PATH"
[[ "$(<"$mock_dir/filename")" == "$(basename "$EVIL_PATH")" ]] \
    || fail "filename field mangled: $(<"$mock_dir/filename")"
[[ "$(<"$mock_dir/api-key")" == "$FAKE_API_KEY" ]] \
    || fail "server did not get the key from ~/.immich_paul_key"

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

# --- Entry point (eg4): main must exit 0 after a successful upload ---
# A RETURN trap set inside upload_file used to fire again when its caller
# (main, or bulk_upload) returned; tmpfile is local to upload_file, so under
# set -u that second firing aborted with "tmpfile: unbound variable" (rc 1).
# Run the script itself with a fake curl first on PATH (never a real server)
# and HOME pointing at KEY_HOME, which holds the made-up key file.
fake_bin="$TEST_ROOT/fake-bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/curl" <<'SH'
#!/usr/bin/env bash
# Fake curl. Ping: 200, except for a URL containing FAKE_DOWN_HOST (LAN
# down). bulk-upload-check: saves the -d @file body and answers
# FAKE_BULK_RESPONSE (default: no duplicates). /api/assets: answers the HTTP
# code in FAKE_UPLOAD_CODE (default 201), or fails like a connection error
# (exit 7, no output) when FAKE_UPLOAD_CODE=curl-error.
# jg4: it also logs its argv and environment, and the curl config read
# from stdin (--config -), where the API key belongs; '.mvals' gets
# 'm=<-m value> url=<url>' per call.
code="${FAKE_UPLOAD_CODE:-201}"
out=""
url=""
m=""
body=""
printf '%s\n' "$*" >>"${FAKE_CURL_LOG:?}"
env >>"${FAKE_CURL_LOG}.env"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        -m) m="$2"; shift 2 ;;
        -d) body="$2"; shift 2 ;;
        --config|-K) [[ "$2" == - ]] && cat >>"${FAKE_CURL_LOG}.stdin"; shift 2 ;;
        *) url="$1"; shift ;;
    esac
done
printf 'm=%s url=%s\n' "$m" "$url" >>"${FAKE_CURL_LOG}.mvals"
case "$url" in
    */api/server/ping)
        if [[ -n "${FAKE_DOWN_HOST:-}" && "$url" == *"$FAKE_DOWN_HOST"* ]]; then
            printf '000'
            exit 7
        fi
        printf '200'
        ;;
    */api/assets/bulk-upload-check)
        [[ "$body" == @* ]] && cat -- "${body#@}" >"${FAKE_CURL_LOG}.bulk-body"
        # FAKE_BULK_FAIL: the check fails like curl -sf on an HTTP error.
        [[ -n "${FAKE_BULK_FAIL:-}" ]] && exit 22
        resp="${FAKE_BULK_RESPONSE:-}"
        [[ -n "$resp" ]] || resp='{"results":[]}'
        printf '%s\n' "$resp"
        ;;
    */api/assets)
        [[ "$code" == curl-error ]] && exit 7
        [[ -n "$out" ]] && printf '%s\n' '{"status":"fake"}' >"$out"
        printf '%s' "$code"
        ;;
    *) exit 7 ;;
esac
SH
chmod +x "$fake_bin/curl"
upload_src="$TEST_ROOT/upload-src"
mkdir -p "$upload_src"
printf 'entry-point-bytes\n' >"$upload_src/photo.jpg"
export FAKE_CURL_LOG="$TEST_ROOT/fake-curl.log"

# run_main TARGET STDERR_FILE — run immich-upload on TARGET through its
# entry point. The key exists only in KEY_HOME's key file, so a hit in the
# fake's argv or environment log can only come from immich-upload.
run_main() {
    HOME="$KEY_HOME" PATH="$fake_bin:$PATH" \
        IMMICH_LAN_URL='http://immich-lan.invalid' \
        IMMICH_PUBLIC_URL='https://immich-public.invalid' \
        "$IMMICH_UPLOAD" "$1" >"$2.out" 2>"$2"
}

# reset_fake_logs — empty every log the fake curl appends to.
reset_fake_logs() {
    local suffix
    for suffix in '' .env .stdin .mvals .bulk-body; do
        : >"${FAKE_CURL_LOG}${suffix}"
    done
}

# --- jg4: the API key must stay off curl's argv and out of its env ---
# argv is world-readable (ps, /proc/<pid>/cmdline). Both the duplicate
# check and the asset upload must get the key as a config header on stdin.
reset_fake_logs
err_file="$TEST_ROOT/main.stderr"
# A directory target runs the bulk duplicate check before the upload.
run_main "$upload_src" "$err_file" \
    || fail "jg4: main exited non-zero: $(<"$err_file")"
grep -Fq 'bulk-upload-check' "$FAKE_CURL_LOG" \
    || fail "jg4: duplicate check did not run: $(cat "$FAKE_CURL_LOG")"
if grep -Fq "$FAKE_API_KEY" "$FAKE_CURL_LOG"; then
    fail "jg4: API key leaked on curl argv: $(cat "$FAKE_CURL_LOG")"
fi
if grep -Fq "$FAKE_API_KEY" "$FAKE_CURL_LOG.env"; then
    fail "jg4: API key leaked into curl environment"
fi
[[ "$(grep -Fxc "header = \"x-api-key: ${FAKE_API_KEY}\"" "$FAKE_CURL_LOG.stdin")" -eq 2 ]] \
    || fail "jg4: API key did not reach both curl calls via --config on stdin"

# q33/r33: same run — every call carried the timeout of its class from
# lib/immich.sh. The duplicate check fails on HTTP errors (-sf); the asset
# upload must not use -f, because it reads the HTTP code (200 = duplicate).
for want_t in "$CURL_PING_TIMEOUT" "$CURL_SEARCH_TIMEOUT" "$CURL_DOWNLOAD_TIMEOUT"; do
    [[ "$want_t" =~ ^[1-9][0-9]*$ ]] \
        || fail "curl timeout is not a positive integer: ${want_t@Q}"
done
grep -qx "m=${CURL_PING_TIMEOUT} url=http://immich-lan.invalid/api/server/ping" \
    "$FAKE_CURL_LOG.mvals" \
    || fail "ping without CURL_PING_TIMEOUT: $(cat "$FAKE_CURL_LOG.mvals")"
grep -qx "m=${CURL_SEARCH_TIMEOUT} url=http://immich-lan.invalid/api/assets/bulk-upload-check" \
    "$FAKE_CURL_LOG.mvals" \
    || fail "duplicate check without CURL_SEARCH_TIMEOUT: $(cat "$FAKE_CURL_LOG.mvals")"
grep -qx "m=${CURL_DOWNLOAD_TIMEOUT} url=http://immich-lan.invalid/api/assets" \
    "$FAKE_CURL_LOG.mvals" \
    || fail "asset upload without CURL_DOWNLOAD_TIMEOUT: $(cat "$FAKE_CURL_LOG.mvals")"
grep -E 'bulk-upload-check$' "$FAKE_CURL_LOG" | grep -Eq '(^| )-sf( |$)' \
    || fail "duplicate check without -sf: $(cat "$FAKE_CURL_LOG")"
if grep -E '/api/assets$' "$FAKE_CURL_LOG" | grep -Eq '(^| )-s?f( |$)'; then
    fail "asset upload uses -f and would hide the HTTP code: $(cat "$FAKE_CURL_LOG")"
fi

# --- Entry point: the duplicate check JSON and its response handling ---
# EVIL_DIR holds only EVIL_PATH (quotes, backslash, comma, semicolon): the
# body sent to bulk-upload-check must be valid JSON naming that exact path.
reset_fake_logs
run_main "$EVIL_DIR" "$err_file" \
    || fail "evil-path dir run failed: $(<"$err_file")"
python3 -c '
import json, sys
data = json.load(open(sys.argv[1]))
assert data["assets"][0]["id"] == sys.argv[2], data
' "$FAKE_CURL_LOG.bulk-body" "$EVIL_PATH" \
    || fail "bulk-upload-check body is not JSON naming EVIL_PATH: $(cat "$FAKE_CURL_LOG.bulk-body")"
# The server reports EVIL_PATH as a duplicate: nothing is uploaded, exit 0.
reset_fake_logs
dup_resp=$(python3 -c '
import json, sys
print(json.dumps({"results": [{"id": sys.argv[1], "action": "reject", "reason": "duplicate"}]}))
' "$EVIL_PATH")
FAKE_BULK_RESPONSE="$dup_resp" run_main "$EVIL_DIR" "$err_file" \
    || fail "all-duplicate run failed: $(<"$err_file")"
grep -q 'Found 1 duplicate(s), 0 file(s) to upload' "$err_file.out" \
    || fail "duplicate not recognised: $(cat "$err_file.out")"
if grep -Eq '/api/assets$' "$FAKE_CURL_LOG"; then
    fail "duplicate EVIL_PATH was uploaded anyway"
fi
# Negative: an unparsable response fails loud instead of uploading all.
reset_fake_logs
if FAKE_BULK_RESPONSE='<html>proxy error</html>' run_main "$EVIL_DIR" "$err_file"; then
    fail "unparsable bulk-upload-check response exited 0"
fi
grep -q 'failed to parse bulk-upload-check response' "$err_file" \
    || fail "missing parse error: $(<"$err_file")"
if grep -Eq '/api/assets$' "$FAKE_CURL_LOG"; then
    fail "uploaded after an unparsable bulk-upload-check response"
fi

# Negative: a failed duplicate check (curl exit 22) stops the run before
# any upload, instead of treating every file as new.
reset_fake_logs
if FAKE_BULK_FAIL=1 run_main "$EVIL_DIR" "$err_file"; then
    fail "failed bulk-upload-check exited 0"
fi
grep -q 'bulk-upload-check failed' "$err_file" \
    || fail "missing bulk-upload-check error: $(<"$err_file")"
grep -Fq 'bulk-upload-check' "$FAKE_CURL_LOG" \
    || fail "duplicate check was not attempted: $(cat "$FAKE_CURL_LOG")"
if grep -Eq '/api/assets$' "$FAKE_CURL_LOG"; then
    fail "uploaded after a failed bulk-upload-check"
fi

# --- Entry point: LAN down fails over to the public URL; no key, no run ---
reset_fake_logs
FAKE_DOWN_HOST='immich-lan.invalid' run_main "$upload_src/photo.jpg" "$err_file" \
    || fail "public failover run failed: $(<"$err_file")"
grep -qx 'm=.* url=https://immich-public.invalid/api/assets' "$FAKE_CURL_LOG.mvals" \
    || fail "upload did not fail over to the public URL: $(cat "$FAKE_CURL_LOG.mvals")"
reset_fake_logs
mv "$KEY_HOME/.immich_paul_key" "$KEY_HOME/key.saved"
if run_main "$upload_src/photo.jpg" "$err_file"; then
    fail "run without an API key file exited 0"
fi
mv "$KEY_HOME/key.saved" "$KEY_HOME/.immich_paul_key"
grep -q 'API key file not found' "$err_file" \
    || fail "missing key-file error: $(<"$err_file")"
[[ ! -s "$FAKE_CURL_LOG" ]] \
    || fail "curl ran without an API key: $(cat "$FAKE_CURL_LOG")"

for target in "$upload_src/photo.jpg" "$upload_src"; do
    err_file="$TEST_ROOT/main.stderr"
    run_main "$target" "$err_file" \
        || fail "main ${target@Q} exited non-zero: $(<"$err_file")"
    if grep -q 'unbound variable' "$err_file"; then
        fail "main ${target@Q} hit unbound variable: $(<"$err_file")"
    fi
done

# --- Entry point (fg4): failed uploads must make main exit non-zero ---
# upload_file used to only warn on a curl error or a non-2xx reply and
# return 0, so a run where every upload failed still exited 0.
for target in "$upload_src/photo.jpg" "$upload_src"; do
    for code in 200 201; do
        err_file="$TEST_ROOT/main.stderr"
        FAKE_UPLOAD_CODE=$code run_main "$target" "$err_file" \
            || fail "main ${target@Q} (HTTP $code) exited non-zero: $(<"$err_file")"
    done
    for code in 500 curl-error; do
        err_file="$TEST_ROOT/main.stderr"
        if FAKE_UPLOAD_CODE=$code run_main "$target" "$err_file"; then
            fail "main ${target@Q} (${code}) exited 0 although the upload failed"
        fi
        grep -q '1 upload(s) failed' "$err_file" \
            || fail "main ${target@Q} (${code}) printed no failure count: $(<"$err_file")"
    done
done

# --- mg4: an unreadable timestamp fails the upload, not uploads it blank ---
# upload_file runs as 'upload_file ... || ...', so set -e is off inside it,
# and a failing date in file_timestamps used to yield empty fileCreatedAt/
# fileModifiedAt that were uploaded anyway (exit 0). A fake date that always
# fails stands in for a file whose mtime cannot be read.
date_fail_bin="$TEST_ROOT/date-fail-bin"
mkdir -p "$date_fail_bin"
printf '#!/usr/bin/env bash\necho "date: fake failure" >&2\nexit 1\n' \
    >"$date_fail_bin/date"
chmod +x "$date_fail_bin/date"
for target in "$upload_src/photo.jpg" "$upload_src"; do
    err_file="$TEST_ROOT/main.stderr"
    : >"$FAKE_CURL_LOG"
    if PATH="$date_fail_bin:$PATH" run_main "$target" "$err_file"; then
        fail "mg4: main ${target@Q} exited 0 although timestamps failed"
    fi
    grep -q 'Failed to read timestamps' "$err_file" \
        || fail "mg4: main ${target@Q} printed no timestamp error: $(<"$err_file")"
    grep -q '1 upload(s) failed' "$err_file" \
        || fail "mg4: main ${target@Q} printed no failure count: $(<"$err_file")"
    if grep -Eq '/api/assets$' "$FAKE_CURL_LOG"; then
        fail "mg4: main ${target@Q} uploaded with unreadable timestamps"
    fi
done

# --- pg4: exact output of a mixed directory run, pinned before the split ---
# One duplicate, one new image, one non-image. Every temp file goes to a
# private TMPDIR, which must be empty afterwards on success and on failure.
pg4_dir="$TEST_ROOT/pg4-src"
pg4_tmp="$TEST_ROOT/pg4-tmp"
mkdir -p "$pg4_dir" "$pg4_tmp"
printf 'dup\n' >"$pg4_dir/a.jpg"
printf 'new\n' >"$pg4_dir/b.png"
printf 'text\n' >"$pg4_dir/c.txt"
pg4_resp=$(python3 -c '
import json, sys
print(json.dumps({"results": [
    {"id": sys.argv[1], "action": "reject", "reason": "duplicate"},
    {"id": sys.argv[2], "action": "accept"}]}))
' "$pg4_dir/a.jpg" "$pg4_dir/b.png")
pg4_head="==> Using LAN ingress: http://immich-lan.invalid
==> Scanning directory: $pg4_dir
==> Found 2 image file(s)
==> Computing SHA1 checksums for 2 file(s)...
==> Checking for duplicates on server...
==> Found 1 duplicate(s), 1 file(s) to upload
[1/1] $pg4_dir/b.png
==> Uploading: b.png"
for pg4_code in 201 200 500 curl-error; do
    reset_fake_logs
    pg4_rc=0
    FAKE_UPLOAD_CODE=$pg4_code FAKE_BULK_RESPONSE="$pg4_resp" TMPDIR="$pg4_tmp" \
        run_main "$pg4_dir" "$err_file" || pg4_rc=$?
    case "$pg4_code" in
        201) pg4_want_out="$pg4_head
==>   Uploaded: b.png" pg4_want_err='' pg4_want_rc=0 ;;
        200) pg4_want_out="$pg4_head
==>   Skipped (duplicate): b.png" pg4_want_err='' pg4_want_rc=0 ;;
        500) pg4_want_out="$pg4_head" pg4_want_err='WARN:   Unexpected response 500 for: b.png
{"status":"fake"}
ERROR: 1 upload(s) failed (of 1 attempted)' pg4_want_rc=1 ;;
        *) pg4_want_out="$pg4_head" pg4_want_err='WARN:   Failed to upload: b.png (curl error)
ERROR: 1 upload(s) failed (of 1 attempted)' pg4_want_rc=1 ;;
    esac
    [[ "$pg4_rc" -eq "$pg4_want_rc" ]] \
        || fail "pg4 $pg4_code: want rc $pg4_want_rc, got $pg4_rc: $(<"$err_file")"
    [[ "$(<"$err_file.out")" == "$pg4_want_out" ]] \
        || fail "pg4 $pg4_code: stdout changed: $(<"$err_file.out")"
    [[ "$(<"$err_file")" == "$pg4_want_err" ]] \
        || fail "pg4 $pg4_code: stderr changed: $(<"$err_file")"
    [[ "$(grep -c '/api/assets$' "$FAKE_CURL_LOG")" -eq 1 ]] \
        || fail "pg4 $pg4_code: want exactly one upload: $(cat "$FAKE_CURL_LOG")"
    [[ -z "$(ls -A "$pg4_tmp")" ]] \
        || fail "pg4 $pg4_code: temp files left behind: $(ls -A "$pg4_tmp")"
done

# pg4: all duplicates -> "Nothing to upload", exit 0, no temp files left.
reset_fake_logs
FAKE_BULK_RESPONSE="$(python3 -c '
import json, sys
print(json.dumps({"results": [
    {"id": p, "action": "reject", "reason": "duplicate"} for p in sys.argv[1:]]}))
' "$pg4_dir/a.jpg" "$pg4_dir/b.png")" TMPDIR="$pg4_tmp" run_main "$pg4_dir" "$err_file" \
    || fail "pg4 all-dup: exited non-zero: $(<"$err_file")"
[[ "$(tail -n 2 "$err_file.out")" == '==> Found 2 duplicate(s), 0 file(s) to upload
==> Nothing to upload.' ]] \
    || fail "pg4 all-dup: output changed: $(<"$err_file.out")"
[[ -z "$(ls -A "$pg4_tmp")" ]] \
    || fail "pg4 all-dup: temp files left behind: $(ls -A "$pg4_tmp")"

# pg4: main's own refusals, each with its exact message and exit 1.
mkdir -p "$TEST_ROOT/pg4-empty"
for pg4_case in missing empty noargs; do
    reset_fake_logs
    pg4_rc=0
    case "$pg4_case" in
        missing) run_main "$TEST_ROOT/no-such" "$err_file" || pg4_rc=$?
            pg4_want="ERROR: Path does not exist: $TEST_ROOT/no-such" ;;
        empty) run_main "$TEST_ROOT/pg4-empty" "$err_file" || pg4_rc=$?
            pg4_want="ERROR: No image files found in: $TEST_ROOT/pg4-empty" ;;
        noargs) "$IMMICH_UPLOAD" >"$err_file.out" 2>"$err_file" || pg4_rc=$?
            pg4_want='ERROR: Usage: immich-upload <file_or_directory>' ;;
    esac
    [[ "$pg4_rc" -eq 1 ]] || fail "pg4 $pg4_case: want rc 1, got $pg4_rc"
    [[ "$(<"$err_file")" == "$pg4_want" ]] \
        || fail "pg4 $pg4_case: stderr changed: $(<"$err_file")"
done

printf 'immich-upload test: ok\n'
