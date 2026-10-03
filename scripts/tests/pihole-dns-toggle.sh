#!/usr/bin/env bash
# Checks for scripts/pihole-dns-toggle strict-mode + set -u smoke (task x33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r TARGET="${SCRIPT_DIR}/../pihole-dns-toggle"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'pihole-dns-toggle test: %s\n' "$*" >&2
    exit 1
}

code_lines() {
    grep -Ev '^[[:space:]]*(#|$)' "$TARGET"
}

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

head -n 5 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
code_lines | grep -Eq '^set -euo pipefail$' \
    || fail "missing set -euo pipefail"
if code_lines | grep -Eq '^#!/bin/bash$'; then
    fail "still uses #!/bin/bash"
fi
if code_lines | grep -Eq '^set -e$'; then
    fail "still uses bare set -e"
fi

# Fail-closed nmcli: temp file + mapfile, not process-sub (masks failures).
code_lines | grep -Fq 'mktemp' \
    || fail "missing mktemp for active-connections list"
if code_lines | grep -Eq '<[[:space:]]*<\('; then
    fail "active connections still use process substitution (masks nmcli failures)"
fi

# u33: DNS list comes from shared inventory (pi2/pi3 + fallbacks).
# Prefer direct greps (avoid pipefail+SIGPIPE from grep -q early-close).
grep -Eq '^[[:space:]]*source[[:space:]].*lib/f3s-hosts\.sh' "$TARGET" \
    || fail "must source lib/f3s-hosts.sh"
grep -Eq '^PIHOLE_DNS="\$F3S_PIHOLE_DNS"' "$TARGET" \
    || fail "PIHOLE_DNS must be set from F3S_PIHOLE_DNS"
if grep -Eq '^PIHOLE_DNS="192\.168\.1\.' "$TARGET"; then
    fail "PIHOLE_DNS still hardcodes literal IPs"
fi

# set -u / mock nmcli smoke: exercise status path without real NetworkManager.
mkdir -p "$TEST_ROOT/bin"
cat >"$TEST_ROOT/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Log invocations for assertions.
printf '%s\n' "$*" >>"${NMCLI_LOG:?}"

case "$1" in
    -t)
        # nmcli -t -f NAME,DEVICE,TYPE connection show --active
        printf '%s\n' 'Wired connection 1:eth0:802-3-ethernet'
        exit 0
        ;;
    -g)
        case "${2:-}" in
            ipv4.ignore-auto-dns)
                printf '%s\n' 'no'
                exit 0
                ;;
            ipv4.dns)
                printf '%s\n' ''
                exit 0
                ;;
        esac
        ;;
    dev)
        if [[ "${2:-}" == show ]]; then
            printf '%s\n' 'GENERAL.DEVICE:                 eth0'
            printf '%s\n' 'IP4.DNS[1]:                     192.168.1.1'
            exit 0
        fi
        ;;
esac

printf 'nmcli mock: unhandled args: %s\n' "$*" >&2
exit 99
EOF
chmod +x "$TEST_ROOT/bin/nmcli"

# Skip OS gate when not on Fedora (script requires /etc/fedora-release).
if [[ ! -f /etc/fedora-release ]]; then
    printf 'pihole-dns-toggle: skipping nmcli smoke (not Fedora)\n'
    printf 'pihole-dns-toggle tests passed\n'
    exit 0
fi

NMCLI_LOG="$TEST_ROOT/nmcli.log"
: >"$NMCLI_LOG"
set +e
PATH="$TEST_ROOT/bin:/usr/bin:/bin" NMCLI_LOG="$NMCLI_LOG" \
    "$TARGET" status >"$TEST_ROOT/status.out" 2>"$TEST_ROOT/status.err"
status=$?
set -e
((status == 0)) || fail "status with mock nmcli failed (exit $status): $(cat "$TEST_ROOT/status.err")"
grep -Eq 'DISABLED|ENABLED' "$TEST_ROOT/status.out" \
    || fail "status output missing ENABLED/DISABLED"
grep -Fq 'connection show --active' "$NMCLI_LOG" \
    || fail "mock nmcli was not asked for active connections"

# nmcli failure must fail closed — not become "No active network connection"
# with a successful (or empty-list) path.
cat >"$TEST_ROOT/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${NMCLI_LOG:?}"
# Fail the active-connections listing (same argv shape as the script).
if [[ "$1" == -t ]]; then
    printf 'nmcli mock: simulated failure\n' >&2
    exit 42
fi
printf 'nmcli mock: unhandled args: %s\n' "$*" >&2
exit 99
EOF
chmod +x "$TEST_ROOT/bin/nmcli"

: >"$NMCLI_LOG"
set +e
PATH="$TEST_ROOT/bin:/usr/bin:/bin" NMCLI_LOG="$NMCLI_LOG" \
    "$TARGET" status >"$TEST_ROOT/fail.out" 2>"$TEST_ROOT/fail.err"
fail_status=$?
set -e
((fail_status != 0)) \
    || fail "nmcli failure exited 0 (should fail closed)"
if grep -Fq 'No active network connection found' \
    "$TEST_ROOT/fail.out" "$TEST_ROOT/fail.err"; then
    fail "nmcli failure misreported as 'No active network connection found'"
fi
grep -Fq 'connection show --active' "$NMCLI_LOG" \
    || fail "failing mock nmcli was not asked for active connections"

# Unbound-variable smoke: script already runs under set -u; a clean status
# exit means no unbound refs on the exercised path.
printf 'pihole-dns-toggle tests passed\n'
