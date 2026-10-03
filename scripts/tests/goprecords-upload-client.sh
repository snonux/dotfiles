#!/usr/bin/env bash
# Checks for scripts/goprecords-upload-client.sh curl timeouts / retries (v33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r CLIENT="${SCRIPT_DIR}/../goprecords-upload-client.sh"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'goprecords-upload-client test: %s\n' "$*" >&2
    exit 1
}

command -v shellcheck >/dev/null 2>&1 \
    || fail "shellcheck not installed"
command -v curl >/dev/null 2>&1 \
    || fail "curl not installed"

sh -n "$CLIENT" || fail "sh -n failed"
# POSIX sh script: shellcheck as dash/sh dialect.
shellcheck -s sh "$CLIENT" || fail "shellcheck failed"

# --- Structural guards ---
grep -Eq '^set -eu$' "$CLIENT" \
    || fail "missing set -eu (POSIX strict mode)"
grep -Fq -- '--connect-timeout' "$CLIENT" \
    || fail "missing --connect-timeout"
grep -Fq -- '--max-time' "$CLIENT" \
    || fail "missing --max-time"
grep -Fq -- '--retry' "$CLIENT" \
    || fail "missing --retry (bounded transient retry)"
grep -Fq 'GOPRECORDS_CONNECT_TIMEOUT' "$CLIENT" \
    || fail "missing GOPRECORDS_CONNECT_TIMEOUT override"
grep -Fq 'GOPRECORDS_MAX_TIME' "$CLIENT" \
    || fail "missing GOPRECORDS_MAX_TIME override"

# Negative structural: bare curl -fsS PUT without timeouts must not remain.
# Require connect-timeout to appear in the same curl invocation block as -X PUT.
upload_block=$(
    awk '
        /^upload\(\)/ { in_fn=1 }
        in_fn && /^}/ { print; exit }
        in_fn { print }
    ' "$CLIENT"
)
printf '%s\n' "$upload_block" | grep -Fq -- '--connect-timeout' \
    || fail "upload() lacks --connect-timeout"
printf '%s\n' "$upload_block" | grep -Fq -- '--max-time' \
    || fail "upload() lacks --max-time"
# Must not use unbounded --retry-all-errors (would retry 401s forever-ish).
if printf '%s\n' "$upload_block" | grep -Fq -- '--retry-all-errors'; then
    fail "upload() must not use --retry-all-errors"
fi

# --- Source helpers (library mode; do not auto-run _main) ---
export TOKEN='test-token'
export GOPRECORDS_HOST='testhost'
export GOPRECORDS_BASE_URL='http://127.0.0.1:9'
export GOPRECORDS_CONNECT_TIMEOUT=2
export GOPRECORDS_MAX_TIME=3
export GOPRECORDS_CURL_RETRIES=0
export GOPRECORDS_CURL_RETRY_DELAY=0
# shellcheck disable=SC1090
GOPRECORDS_UPLOAD_LIB=yes . "$CLIENT"

# --- Unit: skip missing file (no curl) ---
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/calls"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >>"${CURL_SPY_LOG}"
printf '\n' >>"${CURL_SPY_LOG}.lines"
# Also human-readable line for greps.
printf '%s\n' "$*" >>"${CURL_SPY_LOG}.txt"
exit 0
EOF
chmod +x "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH"
export CURL_SPY_LOG="$TEST_ROOT/calls/curl.log"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.txt"

upload 'records' "$TEST_ROOT/does-not-exist" \
    || fail "skip missing file should return 0"
[[ ! -s "$CURL_SPY_LOG" ]] \
    || fail "curl must not run when file is missing"

# --- Positive: spy sees connect/max timeouts on successful upload ---
records_file="$TEST_ROOT/records"
printf 'uptime-records\n' >"$records_file"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.txt"
export GOPRECORDS_CONNECT_TIMEOUT=7
export GOPRECORDS_MAX_TIME=11
export GOPRECORDS_CURL_RETRIES=2
export GOPRECORDS_CURL_RETRY_DELAY=1
upload 'records' "$records_file" || fail "upload with mock curl failed"
grep -Fq -- '--connect-timeout 7' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --connect-timeout 7: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '--max-time 11' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --max-time 11: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '--retry 2' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --retry 2: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '-X PUT' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing -X PUT"
grep -Fq "Authorization: Bearer ${TOKEN}" "${CURL_SPY_LOG}.txt" \
    || fail "spy missing Authorization header"
grep -Fq "${GOPRECORDS_BASE_URL}/upload/${GOPRECORDS_HOST}/records" \
    "${CURL_SPY_LOG}.txt" \
    || fail "spy missing upload URL"

# --- Negative: mock curl exit 22 (HTTP error) must surface ---
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${CURL_SPY_LOG}.txt"
exit 22
EOF
chmod +x "$TEST_ROOT/bin/curl"
: >"${CURL_SPY_LOG}.txt"
set +e
upload 'records' "$records_file" 2>/dev/null
upload_rc=$?
set -e
[[ "$upload_rc" -eq 22 ]] \
    || fail "expected curl exit 22 to propagate, got $upload_rc"

# Restore succeeding spy for later.
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${CURL_SPY_LOG}.txt"
exit 0
EOF
chmod +x "$TEST_ROOT/bin/curl"

# --- Behavioral negative: real curl + silent TCP peer must fail within max-time ---
# Accept TCP, never send HTTP response — without --max-time this hangs forever.
hang_port_file="$TEST_ROOT/hang.port"
hang_py="$TEST_ROOT/hang_server.py"
cat >"$hang_py" <<'PY'
import socket
import sys
import time
from pathlib import Path

port_path = Path(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("127.0.0.1", 0))
sock.listen(1)
port_path.write_text(str(sock.getsockname()[1]), encoding="utf-8")
conn, _ = sock.accept()
# Hold the connection open past the client max-time.
time.sleep(120)
conn.close()
sock.close()
PY
python3 "$hang_py" "$hang_port_file" &
hang_pid=$!
for _ in $(seq 1 50); do
    [[ -s "$hang_port_file" ]] && break
    sleep 0.05
done
[[ -s "$hang_port_file" ]] || fail "hang server did not publish port"
hang_port=$(<"$hang_port_file")

# Use real curl (not PATH spy) for the hang repro.
real_curl=''
for candidate in /usr/bin/curl /bin/curl; do
    if [[ -x "$candidate" ]]; then
        real_curl=$candidate
        break
    fi
done
[[ -x "$real_curl" ]] || fail "could not locate real curl binary"
[[ "$(readlink -f "$real_curl")" != "$(readlink -f "$TEST_ROOT/bin/curl")" ]] \
    || fail "real curl resolved to spy"

# Point PATH away from spy for this measurement; call absolute curl.
start_s=$SECONDS
set +e
"$real_curl" -fsS \
    --connect-timeout 1 \
    --max-time 2 \
    --retry 0 \
    -X PUT --data-binary @"$records_file" \
    -H "Authorization: Bearer test-token" \
    "http://127.0.0.1:${hang_port}/upload/testhost/records" \
    >/dev/null 2>"$TEST_ROOT/hang.err"
hang_rc=$?
set -e
elapsed=$((SECONDS - start_s))
kill "$hang_pid" 2>/dev/null || true
wait "$hang_pid" 2>/dev/null || true

[[ "$hang_rc" -ne 0 ]] \
    || fail "hang server curl unexpectedly succeeded"
# Must fail fast: max-time 2 + small slack; never approach the 120s sleep.
((elapsed <= 8)) \
    || fail "curl hang took ${elapsed}s (expected <=8 with --max-time 2)"

# Same bound via upload() with PATH=real curl only (no spy).
PATH="$(dirname "$real_curl"):/bin:/usr/bin"
export PATH
# Restart hang server for upload() path.
: >"$hang_port_file"
python3 "$hang_py" "$hang_port_file" &
hang_pid=$!
for _ in $(seq 1 50); do
    [[ -s "$hang_port_file" ]] && break
    sleep 0.05
done
[[ -s "$hang_port_file" ]] || fail "hang server (2) did not publish port"
hang_port=$(<"$hang_port_file")
export GOPRECORDS_BASE_URL="http://127.0.0.1:${hang_port}"
export GOPRECORDS_CONNECT_TIMEOUT=1
export GOPRECORDS_MAX_TIME=2
export GOPRECORDS_CURL_RETRIES=0
start_s=$SECONDS
set +e
upload 'records' "$records_file" >/dev/null 2>"$TEST_ROOT/hang2.err"
upload_hang_rc=$?
set -e
elapsed=$((SECONDS - start_s))
kill "$hang_pid" 2>/dev/null || true
wait "$hang_pid" 2>/dev/null || true
[[ "$upload_hang_rc" -ne 0 ]] \
    || fail "upload() against hang server unexpectedly succeeded"
((elapsed <= 8)) \
    || fail "upload() hang took ${elapsed}s (expected <=8 with max-time 2)"

# --- Negative: connect to non-routable addr fails within connect-timeout ---
export GOPRECORDS_BASE_URL='http://172.31.255.254:9'
export GOPRECORDS_CONNECT_TIMEOUT=1
export GOPRECORDS_MAX_TIME=3
export GOPRECORDS_CURL_RETRIES=0
start_s=$SECONDS
set +e
upload 'records' "$records_file" >/dev/null 2>"$TEST_ROOT/conn.err"
conn_rc=$?
set -e
elapsed=$((SECONDS - start_s))
[[ "$conn_rc" -ne 0 ]] \
    || fail "connect to blackhole unexpectedly succeeded"
((elapsed <= 6)) \
    || fail "blackhole connect took ${elapsed}s (expected <=6 with connect-timeout 1)"

# --- _main integration: short timeouts against blackhole must fail fast ---
# (_main prepends system PATH, so a curl spy in TEST_ROOT/bin would lose;
# timeout wiring is already asserted via upload() spy tests above.)
token_dir="$TEST_ROOT/config/goprecords-upload-earth"
mkdir -p "$token_dir"
printf 'tok-earth\n' >"$token_dir/token"

start_s=$SECONDS
set +e
env -i \
    PATH="/bin:/usr/bin:$TEST_ROOT/bin" \
    HOME="$TEST_ROOT/home" \
    GOPRECORDS_HOST=earth \
    GOPRECORDS_TOKEN_FILE="$token_dir/token" \
    GOPRECORDS_RECORDS_FILE="$records_file" \
    GOPRECORDS_BASE_URL='http://172.31.255.254:9' \
    GOPRECORDS_CONNECT_TIMEOUT=1 \
    GOPRECORDS_MAX_TIME=3 \
    GOPRECORDS_CURL_RETRIES=0 \
    GOPRECORDS_CURL_RETRY_DELAY=0 \
    "$CLIENT" >/dev/null 2>"$TEST_ROOT/main-blackhole.err"
main_rc=$?
set -e
elapsed=$((SECONDS - start_s))
[[ "$main_rc" -ne 0 ]] \
    || fail "_main blackhole unexpectedly succeeded"
((elapsed <= 10)) \
    || fail "_main blackhole took ${elapsed}s (expected <=10)"

# --- Negative _main: missing token file ---
set +e
env -i \
    PATH="/bin:/usr/bin" \
    HOME="$TEST_ROOT/home" \
    GOPRECORDS_HOST=earth \
    GOPRECORDS_TOKEN_FILE="$TEST_ROOT/no-such-token" \
    GOPRECORDS_RECORDS_FILE="$records_file" \
    "$CLIENT" >/dev/null 2>"$TEST_ROOT/notoken.err"
notoken_rc=$?
set -e
[[ "$notoken_rc" -ne 0 ]] \
    || fail "missing token should fail _main"
grep -q 'cannot read' "$TEST_ROOT/notoken.err" \
    || fail "missing token error text: $(cat "$TEST_ROOT/notoken.err")"

# --- Negative _main: missing records file override ---
set +e
env -i \
    PATH="/bin:/usr/bin" \
    HOME="$TEST_ROOT/home" \
    GOPRECORDS_HOST=earth \
    GOPRECORDS_TOKEN_FILE="$token_dir/token" \
    GOPRECORDS_RECORDS_FILE="$TEST_ROOT/no-records" \
    "$CLIENT" >/dev/null 2>"$TEST_ROOT/norecords.err"
norecords_rc=$?
set -e
[[ "$norecords_rc" -ne 0 ]] \
    || fail "missing records override should fail _main"
grep -q 'GOPRECORDS_RECORDS_FILE' "$TEST_ROOT/norecords.err" \
    || fail "missing records error text: $(cat "$TEST_ROOT/norecords.err")"

printf 'goprecords-upload-client test: ok\n'
