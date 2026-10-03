#!/usr/bin/env bash
# Unit checks for scripts/lib/immich.sh (task r33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r IMMICH_LIB="${SCRIPT_DIR}/../lib/immich.sh"
declare -r F3S_HOSTS="${SCRIPT_DIR}/../lib/f3s-hosts.sh"
declare -r IMMICH_UPLOAD="${SCRIPT_DIR}/../immich-upload"
declare -r IMMICH_EXPORT="${SCRIPT_DIR}/../immich-export"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'immich-lib test: %s\n' "$*" >&2
    exit 1
}

[[ -f "$IMMICH_LIB" ]] || fail "missing $IMMICH_LIB"
bash -n "$IMMICH_LIB" || fail "bash -n failed"
shellcheck -x -S warning "$IMMICH_LIB" || fail "shellcheck failed"

grep -Eq '^[[:space:]]*source[[:space:]].*f3s-hosts\.sh' "$IMMICH_LIB" \
    || fail "immich.sh must source f3s-hosts.sh"
grep -q 'curl_immich' "$IMMICH_LIB" || fail "missing curl_immich"
grep -q 'detect_immich_url' "$IMMICH_LIB" || fail "missing detect_immich_url"
grep -q '_account_api_key' "$IMMICH_LIB" || fail "missing _account_api_key"

# Drivers must consume the shared lib (not re-embed URL/failover/key helpers).
for consumer in "$IMMICH_UPLOAD" "$IMMICH_EXPORT"; do
    grep -Eq '^[[:space:]]*source[[:space:]].*lib/immich\.sh' "$consumer" \
        || fail "$(basename "$consumer") does not source lib/immich.sh"
done
# Drivers must not redefine detect/reachable (DRY).
for consumer in "$IMMICH_UPLOAD" "$IMMICH_EXPORT"; do
    if grep -Eq '^[[:space:]]*(detect_immich_url|immich_reachable|curl_immich|_safe_account_name|_account_api_key)\(\)' \
        "$consumer"; then
        fail "$(basename "$consumer") redefines a shared immich helper"
    fi
done

# Source lib (idempotent).
# shellcheck source=scripts/lib/immich.sh
source "$IMMICH_LIB"
# shellcheck source=scripts/lib/immich.sh
source "$IMMICH_LIB"

# URL defaults come from inventory when env is unset.
# Use a fresh bash (not a subshell) so inherited readonly CURL_* do not clash.
env -u IMMICH_LAN_URL -u IMMICH_PUBLIC_URL -u IMMICH_URL -u _IMMICH_LIB_SOURCED \
    bash -c '
        set -euo pipefail
        # shellcheck source=scripts/lib/immich.sh
        source "$1"
        [[ "$IMMICH_LAN_URL" == "$F3S_IMMICH_LAN_URL" ]] \
            || { echo "LAN default != inventory: ${IMMICH_LAN_URL@Q}" >&2; exit 1; }
        [[ "$IMMICH_PUBLIC_URL" == "$F3S_IMMICH_PUBLIC_URL" ]] \
            || { echo "public default != inventory: ${IMMICH_PUBLIC_URL@Q}" >&2; exit 1; }
    ' bash "$IMMICH_LIB" \
    || fail "inventory URL default check failed"

# Env overrides inventory defaults.
(
    IMMICH_LAN_URL='http://env-lan.example' \
    IMMICH_PUBLIC_URL='https://env-public.example' \
    bash -c '
        set -euo pipefail
        _IMMICH_LIB_SOURCED=no
        # shellcheck source=scripts/lib/immich.sh
        source "$1"
        [[ "$IMMICH_LAN_URL" == "http://env-lan.example" ]]
        [[ "$IMMICH_PUBLIC_URL" == "https://env-public.example" ]]
    ' bash "$IMMICH_LIB"
) || fail "env URL override failed"

# --- curl_immich always passes -m; -f adds -sf ---
mkdir -p "$TEST_ROOT/bin"
CURL_SPY_LOG="$TEST_ROOT/curl.log"
export CURL_SPY_LOG
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$CURL_SPY_LOG"
exit 0
EOF
chmod +x "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:/usr/bin:/bin"

: >"$CURL_SPY_LOG"
curl_immich 12 -s -o /dev/null 'http://example.test/x' \
    || fail "curl_immich without -f failed"
grep -Eq '(^| )-m 12( |$)' "$CURL_SPY_LOG" \
    || fail "curl_immich missing -m 12: $(cat "$CURL_SPY_LOG")"
if grep -Eq '(^| )-sf( |$)|(^| )-f( |$)' "$CURL_SPY_LOG"; then
    fail "curl_immich without -f should not pass -f/-sf"
fi

: >"$CURL_SPY_LOG"
curl_immich -f 34 -X POST 'http://example.test/y' \
    || fail "curl_immich -f failed"
grep -Eq '(^| )-m 34( |$)' "$CURL_SPY_LOG" \
    || fail "curl_immich -f missing -m 34: $(cat "$CURL_SPY_LOG")"
grep -Eq '(^| )-sf( |$)' "$CURL_SPY_LOG" \
    || fail "curl_immich -f missing -sf: $(cat "$CURL_SPY_LOG")"

# --- detect_immich_url failover (LAN down → public) ---
: >"$CURL_SPY_LOG"
cat >"$TEST_ROOT/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$CURL_SPY_LOG"
url=""
has_m=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m) has_m=1; shift 2 ;;
        -o|-H|-d|-X|-w|--connect-timeout) shift 2 ;;
        -sf|-s|-f|-L|-sL) shift ;;
        http://*|https://*) url="$1"; shift ;;
        *) shift ;;
    esac
done
[[ "$has_m" -eq 1 ]] || { echo "curl spy: missing -m" >&2; exit 2; }
case "$url" in
    *lan.example*/api/server/ping) printf '000'; exit 7 ;;
    *public.example*/api/server/ping) printf '200'; exit 0 ;;
    *) echo "unexpected: $url" >&2; exit 1 ;;
esac
EOF
chmod +x "$TEST_ROOT/bin/curl"
IMMICH_LAN_URL='http://immich.lan.example'
IMMICH_PUBLIC_URL='https://immich.public.example'
IMMICH_URL=''
detect_immich_url >"$TEST_ROOT/out-detect" 2>"$TEST_ROOT/err-detect"
[[ "$IMMICH_URL" == "$IMMICH_PUBLIC_URL" ]] \
    || fail "expected public failover, got ${IMMICH_URL@Q}"
grep -q 'public ingress' "$TEST_ROOT/out-detect" \
    || fail "missing public failover message"

# --- account key load + allowlist ---
declare -r KEY_HOME="$TEST_ROOT/key-home"
mkdir -p "$KEY_HOME"
printf 'secret-key\n' >"$KEY_HOME/.immich_paul_key"
got=$(HOME="$KEY_HOME" _account_api_key paul) \
    || fail "_account_api_key paul failed"
[[ "$got" == 'secret-key' ]] || fail "key got=${got@Q}"
if ( HOME="$KEY_HOME" _account_api_key '../evil' ) >/dev/null 2>&1; then
    fail "_account_api_key accepted path-escaping account"
fi
if _safe_account_name 'foo/bar' >/dev/null 2>&1; then
    fail "_safe_account_name accepted slash"
fi

printf 'immich-lib test: ok\n'
