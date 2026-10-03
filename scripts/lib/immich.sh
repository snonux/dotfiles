# shellcheck shell=bash
# Shared Immich helpers for scripts/immich-upload and scripts/immich-export.
#
# Source this file; do not execute it. Provides URL inventory defaults
# (via f3s-hosts), LAN/public failover, account API-key loading, and a
# curl wrapper that always applies -m (and optional --fail).
#
# SC2034: exported names are the public API for sourcing consumers.
# shellcheck disable=SC2034

[[ "${_IMMICH_LIB_SOURCED:-no}" == yes ]] && return 0
_IMMICH_LIB_SOURCED=yes

_IMMICH_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=f3s-hosts.sh
source "${_IMMICH_LIB_DIR}/f3s-hosts.sh"

# Defaults from inventory; env overrides inventory; CLI may override later.
IMMICH_LAN_URL="${IMMICH_LAN_URL:-$F3S_IMMICH_LAN_URL}"
IMMICH_PUBLIC_URL="${IMMICH_PUBLIC_URL:-$F3S_IMMICH_PUBLIC_URL}"
IMMICH_URL="${IMMICH_URL:-}"

# Curl max-time (seconds). Ping is short; search/API and transfers allow more.
readonly CURL_PING_TIMEOUT=5
readonly CURL_SEARCH_TIMEOUT=60
readonly CURL_DOWNLOAD_TIMEOUT=300

die() { echo "ERROR: $1" >&2; exit 1; }

warn() { echo "WARN: $1" >&2; }

info() { echo "==> $1"; }

# curl_immich [-f] TIMEOUT [curl-args...]
# Always passes -m TIMEOUT. With -f, also passes -sf (silent + HTTP fail).
curl_immich() {
    local fail=no
    if [[ "${1:-}" == -f ]]; then
        fail=yes
        shift
    fi
    local -r timeout="$1"
    shift
    if [[ "$fail" == yes ]]; then
        curl -sf -m "$timeout" "$@"
    else
        curl -m "$timeout" "$@"
    fi
}

# Probe the Immich /api/server/ping endpoint at the given base URL.
# Returns success only on HTTP 200 within a short timeout (follows redirects).
immich_reachable() {
    local url="$1"
    local code
    code=$(curl_immich "$CURL_PING_TIMEOUT" -sL -o /dev/null -w '%{http_code}' \
        "$url/api/server/ping" 2>/dev/null) || return 1
    [[ "$code" == "200" ]]
}

# Pick the LAN URL if reachable, otherwise fall back to the public URL.
# Sets IMMICH_URL. Dies if neither ingress responds.
detect_immich_url() {
    if immich_reachable "$IMMICH_LAN_URL"; then
        IMMICH_URL="$IMMICH_LAN_URL"
        info "Using LAN ingress: $IMMICH_URL"
    elif immich_reachable "$IMMICH_PUBLIC_URL"; then
        IMMICH_URL="$IMMICH_PUBLIC_URL"
        info "LAN ingress unreachable, using public ingress: $IMMICH_URL"
    else
        die "Immich is not reachable via LAN ($IMMICH_LAN_URL) or public ($IMMICH_PUBLIC_URL)"
    fi
}

# _safe_account_name RAW — allowlist a single path-safe account label used under
# DEST_DIR and in ~/.immich_<name>_key. Reject path escape (../elsewhere),
# absolute paths, empty, and any character outside [A-Za-z0-9_-].
_safe_account_name() {
    local -r raw="$1"

    [[ -n "$raw" ]] || return 1
    [[ "$raw" =~ ^[A-Za-z0-9_-]+$ ]] || return 1
    # Defense: allowlist already excludes '/', '.', but keep explicit bans.
    case "$raw" in
        .|..|*"/"*|*"\\"*) return 1 ;;
    esac

    printf '%s\n' "$raw"
}

# _account_api_key NAME — load API key from ~/.immich_<name>_key.
_account_api_key() {
    local account
    account=$(_safe_account_name "$1") \
        || die "Invalid account name: ${1@Q} (allowed: [A-Za-z0-9_-]+)"
    local -r key_file="$HOME/.immich_${account}_key"

    [[ -f "$key_file" ]] || die "API key file not found: $key_file"
    local key
    key=$(cat -- "$key_file")
    [[ -n "$key" ]] || die "API key file is empty: $key_file"
    printf '%s\n' "$key"
}
