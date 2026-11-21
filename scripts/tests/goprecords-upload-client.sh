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
    if [[ -n "${HANG_PID:-}" ]]; then
        kill "$HANG_PID" 2>/dev/null || true
        wait "$HANG_PID" 2>/dev/null || true
    fi
    if [[ -n "${CONN_PID:-}" ]]; then
        kill "$CONN_PID" 2>/dev/null || true
        wait "$CONN_PID" 2>/dev/null || true
    fi
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
command -v python3 >/dev/null 2>&1 \
    || fail "python3 not installed"

sh -n "$CLIENT" || fail "sh -n failed"
# POSIX sh script: shellcheck as dash/sh dialect.
shellcheck -s sh "$CLIENT" || fail "shellcheck failed"

# Kept as source checks: documentation has no behaviour to run. The flags
# and defaults the budget describes are checked through _main further down
# (see run_main_spy); strict mode by the errexit run there.
# Wall-clock budget must be documented in the client header comments.
grep -Fq 'Wall-clock budget' "$CLIENT" \
    || fail "missing wall-clock budget documentation comment"
grep -Fq 'RETRY_MAX_TIME' "$CLIENT" \
    || fail "missing RETRY_MAX_TIME mention in budget docs"

# --- LIB mode: executing with GOPRECORDS_UPLOAD_LIB=yes must still run _main ---
# (Previously this was a silent exit 0 no-op — cron/systemd must always _main.)
set +e
env -i \
    PATH="/bin:/usr/bin" \
    GOPRECORDS_UPLOAD_LIB=yes \
    "$CLIENT" >/dev/null 2>"$TEST_ROOT/lib-exec.err"
lib_exec_rc=$?
set -e
[[ "$lib_exec_rc" -ne 0 ]] \
    || fail "executing with GOPRECORDS_UPLOAD_LIB=yes must not succeed as a no-op"
grep -q 'GOPRECORDS_HOST' "$TEST_ROOT/lib-exec.err" \
    || fail "LIB-exec should reach _main (missing HOST): $(cat "$TEST_ROOT/lib-exec.err")"

# --- Source helpers (library mode; do not auto-run _main) ---
# Made-up secret; not exported, like _main's TOKEN, so the spy can check it
# reaches curl neither through argv nor through the environment.
TOKEN='fake-goprecords-token-7c1e'
export GOPRECORDS_HOST='testhost'
export GOPRECORDS_BASE_URL='http://127.0.0.1:9'
export GOPRECORDS_CONNECT_TIMEOUT=2
export GOPRECORDS_MAX_TIME=3
export GOPRECORDS_CURL_RETRIES=0
export GOPRECORDS_CURL_RETRY_DELAY=0
export GOPRECORDS_CURL_RETRY_MAX_TIME=3
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
# The environment curl sees, to prove the token is not passed that way.
env >>"${CURL_SPY_LOG}.env"
# Capture a curl config read from stdin (--config -): that is where the
# token belongs. Only read stdin when asked to, so the spy never blocks.
prev=''
for arg in "$@"; do
    if [[ "$prev" == --config || "$prev" == -K ]] && [[ "$arg" == - ]]; then
        cat >>"${CURL_SPY_LOG}.stdin"
    fi
    prev=$arg
done
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

# --- Positive: spy sees connect/max/retry flags on successful upload ---
records_file="$TEST_ROOT/records"
printf 'uptime-records\n' >"$records_file"
: >"$CURL_SPY_LOG"
: >"${CURL_SPY_LOG}.txt"
: >"${CURL_SPY_LOG}.env"
: >"${CURL_SPY_LOG}.stdin"
export GOPRECORDS_CONNECT_TIMEOUT=7
export GOPRECORDS_MAX_TIME=11
export GOPRECORDS_CURL_RETRIES=2
export GOPRECORDS_CURL_RETRY_DELAY=1
export GOPRECORDS_CURL_RETRY_MAX_TIME=180
upload 'records' "$records_file" || fail "upload with mock curl failed"
grep -Fq -- '--connect-timeout 7' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --connect-timeout 7: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '--max-time 11' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --max-time 11: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '--retry 2' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --retry 2: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '--retry-delay 1' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --retry-delay 1: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '--retry-max-time 180' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing --retry-max-time 180: $(cat "${CURL_SPY_LOG}.txt")"
grep -Fq -- '-X PUT' "${CURL_SPY_LOG}.txt" \
    || fail "spy missing -X PUT"
# The token must never be on curl's command line (visible to every local
# user in ps and /proc/<pid>/cmdline) nor in its environment; it travels
# as a header line of a curl config read from stdin.
if grep -Fq "$TOKEN" "${CURL_SPY_LOG}.txt"; then
    fail "token leaked on curl argv: $(cat "${CURL_SPY_LOG}.txt")"
fi
if grep -Fq "$TOKEN" "${CURL_SPY_LOG}.env"; then
    fail "token leaked into curl environment"
fi
grep -Fxq "header = \"Authorization: Bearer ${TOKEN}\"" \
    "${CURL_SPY_LOG}.stdin" 2>/dev/null \
    || fail "token did not reach curl via --config on stdin"
grep -Fq "${GOPRECORDS_BASE_URL}/upload/${GOPRECORDS_HOST}/records" \
    "${CURL_SPY_LOG}.txt" \
    || fail "spy missing upload URL"

# ug4: a token holding '"' and '\' is escaped for the quoted config string
# (backslash doubled first, then quote -> \"), so curl decodes it back to
# the original token instead of ending or escaping the string early.
saved_token=$TOKEN
TOKEN='fake"tok\en'
: >"${CURL_SPY_LOG}.txt"
: >"${CURL_SPY_LOG}.stdin"
upload 'records' "$records_file" || fail "upload with quote/backslash token failed"
grep -Fxq 'header = "Authorization: Bearer fake\"tok\\en"' \
    "${CURL_SPY_LOG}.stdin" \
    || fail "quote/backslash token not escaped in config: $(cat "${CURL_SPY_LOG}.stdin")"
[[ "$(wc -l <"${CURL_SPY_LOG}.stdin")" -eq 1 ]] \
    || fail "config for quote/backslash token is not one line"
if grep -Fq 'fake"tok' "${CURL_SPY_LOG}.txt"; then
    fail "quote/backslash token leaked on curl argv"
fi
TOKEN=$saved_token

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

# Locate real curl once (PATH spy must not shadow hang/connect measurements).
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

# --- Behavioral: upload()-wired hang against silent TCP peer ---
# Accept TCP, never send HTTP — without --max-time this hangs forever.
# This is the real assertion (upload() wiring); not a bare absolute-curl call.
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
# Hold the connection open past the client max-time / retry budget.
time.sleep(120)
conn.close()
sock.close()
PY

PATH="$(dirname "$real_curl"):/bin:/usr/bin"
export PATH

: >"$hang_port_file"
python3 "$hang_py" "$hang_port_file" &
HANG_PID=$!
for _ in $(seq 1 50); do
    [[ -s "$hang_port_file" ]] && break
    sleep 0.05
done
[[ -s "$hang_port_file" ]] || fail "hang server did not publish port"
hang_port=$(<"$hang_port_file")
export GOPRECORDS_BASE_URL="http://127.0.0.1:${hang_port}"
export GOPRECORDS_CONNECT_TIMEOUT=1
export GOPRECORDS_MAX_TIME=2
export GOPRECORDS_CURL_RETRIES=0
export GOPRECORDS_CURL_RETRY_DELAY=0
export GOPRECORDS_CURL_RETRY_MAX_TIME=2
start_s=$SECONDS
set +e
upload 'records' "$records_file" >/dev/null 2>"$TEST_ROOT/hang.err"
upload_hang_rc=$?
set -e
elapsed=$((SECONDS - start_s))
kill "$HANG_PID" 2>/dev/null || true
wait "$HANG_PID" 2>/dev/null || true
HANG_PID=
[[ "$upload_hang_rc" -ne 0 ]] \
    || fail "upload() against hang server unexpectedly succeeded"
# Must fail fast: max-time 2 + small slack; never approach the 120s sleep.
((elapsed <= 8)) \
    || fail "upload() hang took ${elapsed}s (expected <=8 with max-time 2)"

# --- Behavioral: production-like retries against hang (wall-clock ceiling) ---
# Defaults use RETRIES=2; without --retry-max-time worst case ≈ (2+1)*max-time.
# With retry-max-time=6 and max-time=2, total must stay near the retry ceiling.
: >"$hang_port_file"
python3 "$hang_py" "$hang_port_file" &
HANG_PID=$!
for _ in $(seq 1 50); do
    [[ -s "$hang_port_file" ]] && break
    sleep 0.05
done
[[ -s "$hang_port_file" ]] || fail "hang server (retry) did not publish port"
hang_port=$(<"$hang_port_file")
export GOPRECORDS_BASE_URL="http://127.0.0.1:${hang_port}"
export GOPRECORDS_CONNECT_TIMEOUT=1
export GOPRECORDS_MAX_TIME=2
export GOPRECORDS_CURL_RETRIES=2
export GOPRECORDS_CURL_RETRY_DELAY=0
export GOPRECORDS_CURL_RETRY_MAX_TIME=6
start_s=$SECONDS
set +e
upload 'records' "$records_file" >/dev/null 2>"$TEST_ROOT/hang-retry.err"
upload_retry_rc=$?
set -e
elapsed=$((SECONDS - start_s))
kill "$HANG_PID" 2>/dev/null || true
wait "$HANG_PID" 2>/dev/null || true
HANG_PID=
[[ "$upload_retry_rc" -ne 0 ]] \
    || fail "upload() retry hang unexpectedly succeeded"
# Ceiling: retry-max-time 6 + slack. Must not approach 3*max-time unbounded.
((elapsed <= 14)) \
    || fail "upload() retry hang took ${elapsed}s (expected <=14 with retry-max-time 6)"
# Should exercise more than a single max-time=2 attempt under RETRIES=2.
((elapsed >= 2)) \
    || fail "upload() retry hang finished too fast (${elapsed}s); retries may be inert"

# --- Negative: connect-timeout via local backlog-full sink (not wg0-routed IP) ---
# listen(0) + one completed handshake fills the accept queue; further SYNs are
# dropped so curl's --connect-timeout fires. Reliable on hosts with wg0.
conn_port_file="$TEST_ROOT/conn.port"
conn_py="$TEST_ROOT/conn_sink.py"
cat >"$conn_py" <<'PY'
import socket
import sys
import time
from pathlib import Path

port_path = Path(sys.argv[1])
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("127.0.0.1", 0))
sock.listen(0)
port = sock.getsockname()[1]
port_path.write_text(str(port), encoding="utf-8")
filler = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
filler.settimeout(2)
filler.connect(("127.0.0.1", port))
# Keep filler + listening sock alive; do not accept — backlog stays full.
time.sleep(3600)
PY
python3 "$conn_py" "$conn_port_file" &
CONN_PID=$!
for _ in $(seq 1 50); do
    [[ -s "$conn_port_file" ]] && break
    sleep 0.05
done
[[ -s "$conn_port_file" ]] || fail "connect sink did not publish port"
conn_port=$(<"$conn_port_file")
export GOPRECORDS_BASE_URL="http://127.0.0.1:${conn_port}"
export GOPRECORDS_CONNECT_TIMEOUT=1
export GOPRECORDS_MAX_TIME=3
export GOPRECORDS_CURL_RETRIES=0
export GOPRECORDS_CURL_RETRY_DELAY=0
export GOPRECORDS_CURL_RETRY_MAX_TIME=3
start_s=$SECONDS
set +e
upload 'records' "$records_file" >/dev/null 2>"$TEST_ROOT/conn.err"
conn_rc=$?
set -e
elapsed=$((SECONDS - start_s))
[[ "$conn_rc" -ne 0 ]] \
    || fail "connect to backlog-full sink unexpectedly succeeded"
((elapsed <= 6)) \
    || fail "connect sink took ${elapsed}s (expected <=6 with connect-timeout 1)"

# --- _main integration: short timeouts against same local connect sink ---
token_dir="$TEST_ROOT/config/goprecords-upload-earth"
mkdir -p "$token_dir"
printf 'tok-earth\n' >"$token_dir/token"

start_s=$SECONDS
set +e
env -i \
    PATH="/bin:/usr/bin" \
    HOME="$TEST_ROOT/home" \
    GOPRECORDS_HOST=earth \
    GOPRECORDS_TOKEN_FILE="$token_dir/token" \
    GOPRECORDS_RECORDS_FILE="$records_file" \
    GOPRECORDS_BASE_URL="http://127.0.0.1:${conn_port}" \
    GOPRECORDS_CONNECT_TIMEOUT=1 \
    GOPRECORDS_MAX_TIME=3 \
    GOPRECORDS_CURL_RETRIES=0 \
    GOPRECORDS_CURL_RETRY_DELAY=0 \
    GOPRECORDS_CURL_RETRY_MAX_TIME=3 \
    "$CLIENT" >/dev/null 2>"$TEST_ROOT/main-conn.err"
main_rc=$?
set -e
elapsed=$((SECONDS - start_s))
kill "$CONN_PID" 2>/dev/null || true
wait "$CONN_PID" 2>/dev/null || true
CONN_PID=
[[ "$main_rc" -ne 0 ]] \
    || fail "_main connect sink unexpectedly succeeded"
((elapsed <= 10)) \
    || fail "_main connect sink took ${elapsed}s (expected <=10)"

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

# --- ug4 _main with real curl: a token holding '"' and '\' is accepted and
# arrives at a local listener unchanged. The token file also holds a CR/LF
# and a second line shaped like a config directive: _main strips CR/LF, so
# that text stays inside the one header value and never becomes a config
# line of its own (no X-Evil header reaches the server). ---
auth_py="$TEST_ROOT/auth_sink.py"
cat >"$auth_py" <<'PY'
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

port_path, log_path = Path(sys.argv[1]), Path(sys.argv[2])


class Handler(BaseHTTPRequestHandler):
    def do_PUT(self):
        self.rfile.read(int(self.headers.get("Content-Length", "0")))
        with log_path.open("a", encoding="utf-8") as log:
            log.write("auth=%s\n" % self.headers.get("Authorization", ""))
            log.write("evil=%s\n" % self.headers.get("X-Evil", ""))
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
port_path.write_text(str(server.server_port), encoding="utf-8")
server.serve_forever()
PY
auth_port_file="$TEST_ROOT/auth.port"
auth_log="$TEST_ROOT/auth.log"
: >"$auth_log"
python3 "$auth_py" "$auth_port_file" "$auth_log" &
CONN_PID=$!
for _ in $(seq 1 50); do
    [[ -s "$auth_port_file" ]] && break
    sleep 0.05
done
[[ -s "$auth_port_file" ]] || fail "auth sink did not publish port"
printf 'fake"tok\\en\r\nheader = "X-Evil: 1"\n' >"$TEST_ROOT/quote-token"
set +e
env -i \
    PATH="/bin:/usr/bin" \
    HOME="$TEST_ROOT/home" \
    GOPRECORDS_HOST=earth \
    GOPRECORDS_TOKEN_FILE="$TEST_ROOT/quote-token" \
    GOPRECORDS_RECORDS_FILE="$records_file" \
    GOPRECORDS_BASE_URL="http://127.0.0.1:$(<"$auth_port_file")" \
    GOPRECORDS_CURL_RETRIES=0 \
    "$CLIENT" >/dev/null 2>"$TEST_ROOT/quotetoken.err"
quotetoken_rc=$?
set -e
kill "$CONN_PID" 2>/dev/null || true
wait "$CONN_PID" 2>/dev/null || true
CONN_PID=
[[ "$quotetoken_rc" -eq 0 ]] \
    || fail "_main refused a quote/backslash token: $(cat "$TEST_ROOT/quotetoken.err")"
grep -Fxq 'auth=Bearer fake"tok\enheader = "X-Evil: 1"' "$auth_log" \
    || fail "token did not arrive unchanged: $(cat "$auth_log")"
if grep -q '^evil=.' "$auth_log"; then
    fail "a token line break became a config line: $(cat "$auth_log")"
fi

# --- _main with a curl spy: flags, env overrides, defaults, errexit ---
# _main puts /bin and /usr/bin before the caller's PATH, so a fake curl on
# PATH would be shadowed by the real one. Instead a fresh bash sources the
# client (its top level reads the GOPRECORDS_* env as in production), turns
# curl into a shell function, which wins over any PATH lookup, and runs
# _main. The spy logs one argv line per call, drains the config on stdin,
# and returns SPY_RC.
# run_main_spy LOG [VAR=VALUE...]
run_main_spy() {
    local -r log="$1"
    shift
    : >"$log"
    # shellcheck disable=SC2016 # the child bash expands these
    env -i \
        PATH="/bin:/usr/bin" \
        HOME="$TEST_ROOT/home" \
        GOPRECORDS_HOST=earth \
        GOPRECORDS_TOKEN_FILE="$token_dir/token" \
        GOPRECORDS_RECORDS_FILE="$records_file" \
        SPY_LOG="$log" \
        "$@" \
        bash -c '
GOPRECORDS_UPLOAD_LIB=yes . "$1"
curl() { printf "%s\n" "$*" >>"$SPY_LOG"; cat >/dev/null; return "${SPY_RC:-0}"; }
_main
' bash "$CLIENT"
}

# assert_every_call LOG LABEL FLAG_AND_VALUE... — every logged curl call
# carries each given flag with its value, and there is at least one call.
assert_every_call() {
    local -r log="$1" label="$2"
    shift 2
    grep -q "/upload/earth/records" "$log" \
        || fail "$label: no records upload: $(cat "$log")"
    local want
    for want in "$@"; do
        if grep -Fv -- " $want " "$log" | grep -q .; then
            fail "$label: a curl call lacks '$want': $(cat "$log")"
        fi
    done
    if grep -Fq -- '--retry-all-errors' "$log"; then
        fail "$label: --retry-all-errors would retry 401s"
    fi
}

spy_log="$TEST_ROOT/main-spy.log"
run_main_spy "$spy_log" || fail "_main spy run (defaults) failed"
# Defaults documented as the wall-clock budget: 10s connect, 60s per
# transfer, 2 retries 1s apart, 180s total retry ceiling.
assert_every_call "$spy_log" defaults \
    '--connect-timeout 10' '--max-time 60' '--retry 2' \
    '--retry-delay 1' '--retry-max-time 180'
run_main_spy "$spy_log" \
    GOPRECORDS_CONNECT_TIMEOUT=7 GOPRECORDS_MAX_TIME=11 \
    GOPRECORDS_CURL_RETRIES=3 GOPRECORDS_CURL_RETRY_DELAY=4 \
    GOPRECORDS_CURL_RETRY_MAX_TIME=99 \
    || fail "_main spy run (overrides) failed"
assert_every_call "$spy_log" overrides \
    '--connect-timeout 7' '--max-time 11' '--retry 3' \
    '--retry-delay 4' '--retry-max-time 99'
# set -e: the first failed upload stops _main with curl's status.
set +e
run_main_spy "$spy_log" SPY_RC=22
spy_fail_rc=$?
set -e
[[ "$spy_fail_rc" -eq 22 ]] \
    || fail "_main after a failed upload: want rc 22, got $spy_fail_rc"
[[ "$(wc -l <"$spy_log")" -eq 1 ]] \
    || fail "_main kept uploading after a failure: $(cat "$spy_log")"

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

# --- pg4: upload order and payloads, pinned before _main was split ---
# The spy logs "<kind> <first line of the uploaded file>" per call. A
# uprecords shell function stands in for the real tool; UPREC_CUR=yes adds
# a current-session line ('->'), which is what triggers the cur.txt upload.
# Only the branches this host can reach are pinned: /etc/os-release and
# /proc/cpuinfo exist here, so the dmesg/uname/sysctl fallbacks are not run.
# run_main_pg4 LOG [VAR=VALUE...]
run_main_pg4() {
    local -r log="$1"
    shift
    : >"$log"
    # shellcheck disable=SC2016 # the child bash expands these
    env -i \
        PATH="/bin:/usr/bin" \
        HOME="$TEST_ROOT/home" \
        GOPRECORDS_HOST=earth \
        GOPRECORDS_TOKEN_FILE="$token_dir/token" \
        GOPRECORDS_RECORDS_FILE="$records_file" \
        SPY_LOG="$log" \
        "$@" \
        bash -c '
GOPRECORDS_UPLOAD_LIB=yes . "$1"
curl() {
    local file="" url=""
    while [ $# -gt 0 ]; do
        case $1 in
            --data-binary) file=${2#@}; shift 2 ;;
            http*) url=$1; shift ;;
            *) shift ;;
        esac
    done
    cat >/dev/null
    printf "%s %s\n" "${url##*/}" "$(head -n 1 "$file")" >>"$SPY_LOG"
}
uprecords() {
    if [ "$*" = "-a -m 100" ]; then echo "uprecords-table"; return; fi
    echo "     1  some old session"
    [ "${UPREC_CUR:-}" = yes ] && echo "->   2  current session"
    return 0
}
_main
' bash "$CLIENT"
}
pg4_log="$TEST_ROOT/pg4-spy.log"
[[ -r /etc/os-release && -r /proc/cpuinfo ]] \
    || fail "pg4: this check expects /etc/os-release and /proc/cpuinfo"
pg4_tail="os.txt $(head -n 1 /etc/os-release)
cpuinfo.txt $(head -n 1 /proc/cpuinfo)"
pg4_records="records $(head -n 1 "$records_file")"
run_main_pg4 "$pg4_log" || fail "pg4: _main run failed"
[[ "$(cat "$pg4_log")" == "$pg4_records
txt uprecords-table
$pg4_tail" ]] || fail "pg4: uploads changed: $(cat "$pg4_log")"
run_main_pg4 "$pg4_log" UPREC_CUR=yes || fail "pg4: _main run (cur) failed"
[[ "$(cat "$pg4_log")" == "$pg4_records
txt uprecords-table
cur.txt ->   2  current session
$pg4_tail" ]] || fail "pg4: uploads with a current session changed: $(cat "$pg4_log")"

printf 'goprecords-upload-client test: ok\n'
