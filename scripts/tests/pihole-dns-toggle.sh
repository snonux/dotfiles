#!/usr/bin/env bash
# Checks for scripts/pihole-dns-toggle strict-mode + set -u smoke (task x33)
# and argument validation: unknown args and --help never touch nmcli (ig4).
# nmcli is always a logging fake on PATH; real DNS is never changed.
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

bash -n "$TARGET" || fail "bash -n failed"
shellcheck -x -S warning "$TARGET" || fail "shellcheck failed"

# Kept as a source check: env-bash over /bin/bash only matters on hosts
# without /bin/bash, so this machine cannot observe it.
head -n 1 "$TARGET" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
# Strict mode, fail-closed nmcli listing (no process substitution) and the
# inventory DNS list are checked by running the script below, not grepped.

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
        # mg4: NMCLI_FAIL_GET=1 makes both DNS-state queries fail;
        # NMCLI_FAIL_GET=<field> fails only the query for that field.
        if [[ "${NMCLI_FAIL_GET:-}" == 1 || "${NMCLI_FAIL_GET:-}" == "${2:-}" ]]; then
            printf 'nmcli mock: simulated query failure\n' >&2
            exit 42
        fi
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
    con)
        # con mod / con up: the DNS-changing calls. Only logged, never real.
        case "${2:-}" in
            mod|up) exit 0 ;;
        esac
        ;;
esac

printf 'nmcli mock: unhandled args: %s\n' "$*" >&2
exit 99
EOF
chmod +x "$TEST_ROOT/bin/nmcli"

# run_target <name> [args...]: run the script against the mock nmcli with
# a fresh call log; sets run_status, output in $TEST_ROOT/<name>.{out,err}.
run_target() {
    local name="$1"
    shift
    : >"$NMCLI_LOG"
    set +e
    PATH="$TEST_ROOT/bin:/usr/bin:/bin" NMCLI_LOG="$NMCLI_LOG" \
        "$TARGET" "$@" >"$TEST_ROOT/$name.out" 2>"$TEST_ROOT/$name.err"
    run_status=$?
    set -e
}

NMCLI_LOG="$TEST_ROOT/nmcli.log"

# ig4: an unknown argument (typo) must print usage and exit 2 without any
# nmcli call; -h/--help prints usage and exits 0. Previously both fell into
# the toggle arm and rewrote DNS. Arguments are validated before the OS
# gate, so these checks run on any distro.
for bad_arg in bogus stauts -x; do
    run_target unknown "$bad_arg"
    ((run_status == 2)) \
        || fail "'$bad_arg' exited $run_status, want 2"
    grep -Fq 'Usage:' "$TEST_ROOT/unknown.err" \
        || fail "'$bad_arg' did not print usage on stderr"
    if [[ -s "$NMCLI_LOG" ]]; then
        fail "'$bad_arg' called nmcli: $(cat "$NMCLI_LOG")"
    fi
done
for help_arg in -h --help help; do
    run_target help "$help_arg"
    ((run_status == 0)) \
        || fail "'$help_arg' exited $run_status, want 0"
    grep -Fq 'Usage:' "$TEST_ROOT/help.out" \
        || fail "'$help_arg' did not print usage on stdout"
    if [[ -s "$NMCLI_LOG" ]]; then
        fail "'$help_arg' called nmcli: $(cat "$NMCLI_LOG")"
    fi
done
run_target extra status bogus
((run_status == 2)) || fail "two arguments exited $run_status, want 2"
if [[ -s "$NMCLI_LOG" ]]; then
    fail "two arguments called nmcli: $(cat "$NMCLI_LOG")"
fi

# Skip OS gate when not on Fedora (script requires /etc/fedora-release).
if [[ ! -f /etc/fedora-release ]]; then
    printf 'pihole-dns-toggle: skipping nmcli smoke (not Fedora)\n'
    printf 'pihole-dns-toggle tests passed\n'
    exit 0
fi

# Negative for ig4: 'toggle' and no argument still toggle (mock reports
# Pi-hole disabled, so both must enable it via con mod + con up).
for toggle_args in toggle ''; do
    if [[ -n "$toggle_args" ]]; then
        run_target toggle "$toggle_args"
    else
        run_target toggle
    fi
    ((run_status == 0)) \
        || fail "toggle '${toggle_args}' exited $run_status: $(cat "$TEST_ROOT/toggle.err")"
    grep -Fq 'con mod Wired connection 1 ipv4.ignore-auto-dns yes' "$NMCLI_LOG" \
        || fail "toggle '${toggle_args}' did not enable Pi-hole DNS"
    grep -Fq 'con up Wired connection 1' "$NMCLI_LOG" \
        || fail "toggle '${toggle_args}' did not bring the connection up"
done

# u33: 'on' writes the inventory's F3S_PIHOLE_DNS (lib/f3s-hosts.sh) as
# the connection's DNS list.
# shellcheck disable=SC2016 # the child bash expands $1
inv_dns=$(bash -c 'source "$1"; printf %s "$F3S_PIHOLE_DNS"' \
    bash "${SCRIPT_DIR}/../lib/f3s-hosts.sh") || fail "cannot read inventory"
[[ -n "$inv_dns" ]] || fail "inventory has no F3S_PIHOLE_DNS"
run_target on on
((run_status == 0)) || fail "on exited $run_status: $(cat "$TEST_ROOT/on.err")"
grep -Fxq "con mod Wired connection 1 ipv4.dns $inv_dns" "$NMCLI_LOG" \
    || fail "on did not set the inventory DNS list: $(cat "$NMCLI_LOG")"
# A copy of the unmodified script beside a stub inventory follows the stub,
# so the list is not a hardcoded copy of the inventory's IPs.
mkdir -p "$TEST_ROOT/layout/lib"
cp "$TARGET" "$TEST_ROOT/layout/pihole-dns-toggle"
printf '%s\n' "F3S_PIHOLE_DNS='10.9.9.1 10.9.9.2'" \
    >"$TEST_ROOT/layout/lib/f3s-hosts.sh"
: >"$NMCLI_LOG"
PATH="$TEST_ROOT/bin:/usr/bin:/bin" NMCLI_LOG="$NMCLI_LOG" \
    "$TEST_ROOT/layout/pihole-dns-toggle" on >/dev/null 2>"$TEST_ROOT/stub.err" \
    || fail "stub-inventory on failed: $(cat "$TEST_ROOT/stub.err")"
grep -Fxq 'con mod Wired connection 1 ipv4.dns 10.9.9.1 10.9.9.2' "$NMCLI_LOG" \
    || fail "DNS list does not follow lib/f3s-hosts.sh: $(cat "$NMCLI_LOG")"

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

# mg4: a failed DNS-state query must not read as "disabled". The check runs
# under 'if', where set -e is off, so toggle used to go on and rewrite DNS
# (enable Pi-hole) and status printed DISABLED, both with exit 0.
# Each query is failed on its own too, so every check is pinned.
for fail_get in 1 ipv4.ignore-auto-dns ipv4.dns; do
    export NMCLI_FAIL_GET="$fail_get"
    for state_args in toggle status; do
        run_target "query-fail-$state_args" "$state_args"
        ((run_status != 0)) \
            || fail "$state_args with failing nmcli query ($fail_get) exited 0"
        grep -Fq 'cannot read the DNS settings' "$TEST_ROOT/query-fail-$state_args.err" \
            || fail "$state_args with failing query ($fail_get): no error: $(cat "$TEST_ROOT/query-fail-$state_args.err")"
        if grep -Eq '^con (mod|up)' "$NMCLI_LOG"; then
            fail "$state_args with failing query ($fail_get) changed DNS: $(cat "$NMCLI_LOG")"
        fi
        if grep -Eq 'ENABLED|DISABLED' "$TEST_ROOT/query-fail-$state_args.out"; then
            fail "$state_args with failing query ($fail_get) reported a state"
        fi
    done
done
unset NMCLI_FAIL_GET

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
