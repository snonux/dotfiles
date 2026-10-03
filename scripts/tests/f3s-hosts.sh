#!/usr/bin/env bash
# Checks for scripts/lib/f3s-hosts.sh inventory + consumer wiring (task u33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r LIB="${SCRIPT_DIR}/../lib/f3s-hosts.sh"
declare -r WOL_F3S="${SCRIPT_DIR}/../wol-f3s"
declare -r PIHOLE="${SCRIPT_DIR}/../pihole-dns-toggle"
declare -r HOME_BACKUP="${SCRIPT_DIR}/../home-backup"
declare -r TEMP_BACKUP="${SCRIPT_DIR}/../temp-backup"

fail() {
    printf 'f3s-hosts test: %s\n' "$*" >&2
    exit 1
}

# Match PATTERN against non-comment lines only (avoid pipefail+SIGPIPE
# from grep -q early-close on a pipeline).
code_match() {
    local -r file="$1"
    local -r pattern="$2"
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        if [[ "$line" =~ $pattern ]]; then
            return 0
        fi
    done <"$file"
    return 1
}

[[ -f "$LIB" ]] || fail "missing inventory: $LIB"
bash -n "$LIB" || fail "bash -n failed on lib"
shellcheck -x -S warning "$LIB" || fail "shellcheck failed on lib"

# shellcheck source=scripts/lib/f3s-hosts.sh
source "$LIB"

[[ "${F3S_HOST_IP[f0]}" == "192.168.1.130" ]] \
    || fail "f0 IP drift: ${F3S_HOST_IP[f0]}"
[[ "${F3S_HOST_MAC[f0]}" == "e8:ff:1e:d7:1c:ac" ]] \
    || fail "f0 MAC drift: ${F3S_HOST_MAC[f0]}"
[[ "$(f3s_host_ip f2)" == "192.168.1.132" ]] \
    || fail "f3s_host_ip f2 failed"
[[ "$(f3s_host_mac f3)" == "e8:ff:1e:d7:f3:d7" ]] \
    || fail "f3s_host_mac f3 failed"
f3s_host_ip nosuch && fail "f3s_host_ip should fail for unknown host"
f3s_host_mac pi0 && fail "f3s_host_mac should fail for Pi (no WoL)"

# Pi-hole DNS must be derived from pi2/pi3 + fallbacks (no hard drift).
want_dns="${F3S_HOST_IP[pi2]} ${F3S_HOST_IP[pi3]} ${F3S_DNS_FALLBACK} ${F3S_LAN_GATEWAY}"
[[ "$F3S_PIHOLE_DNS" == "$want_dns" ]] \
    || fail "F3S_PIHOLE_DNS=$F3S_PIHOLE_DNS want $want_dns"

[[ "$F3S_HOME_BACKUP_HOST" == "f2.lan" ]] || fail "home-backup host role"
[[ "$F3S_TEMP_BACKUP_HOST" == "f0.wg0" ]] || fail "temp-backup host role"
[[ "$F3S_SHELLY_IP" == "192.168.1.28" ]] || fail "Shelly IP"
[[ "${#F3S_GOGIOS_GATEWAYS[@]}" -eq 2 ]] || fail "Gogios gateways count"
[[ "${#F3S_BEELINKS[@]}" -eq 4 ]] || fail "Beelink count"
[[ "${#F3S_BEELINKS_DEFAULT[@]}" -eq 3 ]] || fail "default Beelink wake set"
[[ "${#F3S_PIS[@]}" -eq 4 ]] || fail "Pi count"
[[ "${#F3S_K3S_NODES[@]}" -eq 3 ]] || fail "k3s node count"

# Idempotent source
# shellcheck source=scripts/lib/f3s-hosts.sh
source "$LIB"

# Consumers must source the inventory (not re-embed fleet facts).
# Match a real source line (not a # shellcheck / doc comment mention).
for consumer in "$WOL_F3S" "$PIHOLE" "$HOME_BACKUP" "$TEMP_BACKUP"; do
    bash -n "$consumer" || fail "bash -n failed: $consumer"
    shellcheck -x -S warning "$consumer" \
        || fail "shellcheck failed: $consumer"
    grep -Eq '^[[:space:]]*source[[:space:]].*lib/f3s-hosts\.sh' \
        "$consumer" \
        || fail "$consumer does not source lib/f3s-hosts.sh"
done

# wol-f3s must not re-declare literal Beelink IPs/MACs as primary inventory.
code_match "$WOL_F3S" '^F0_IP="192\.168\.1\.130"' \
    && fail "wol-f3s still hardcodes F0_IP literal"
code_match "$WOL_F3S" '^F0_MAC="e8:ff:1e:d7:1c:ac"' \
    && fail "wol-f3s still hardcodes F0_MAC literal"
code_match "$WOL_F3S" 'F0_IP="\$\{F3S_HOST_IP\[f0\]\}"' \
    || fail "wol-f3s must alias F0_IP from F3S_HOST_IP[f0]"

# pihole must use inventory DNS string, not a private literal list.
code_match "$PIHOLE" '^PIHOLE_DNS="192\.168\.1\.' \
    && fail "pihole-dns-toggle still hardcodes PIHOLE_DNS literals"
code_match "$PIHOLE" 'PIHOLE_DNS="\$F3S_PIHOLE_DNS"' \
    || fail "pihole-dns-toggle must set PIHOLE_DNS from F3S_PIHOLE_DNS"

# home-backup / temp-backup role hosts from inventory.
code_match "$HOME_BACKUP" 'F3S_HOME_BACKUP_HOST' \
    || fail "home-backup must reference F3S_HOME_BACKUP_HOST"
code_match "$HOME_BACKUP" 'paul@f2\.lan:' \
    && fail "home-backup still hardcodes paul@f2.lan"
code_match "$TEMP_BACKUP" 'F3S_TEMP_BACKUP_HOST' \
    || fail "temp-backup must reference F3S_TEMP_BACKUP_HOST"
code_match "$TEMP_BACKUP" 'TEMP_BACKUP_HOST:-f0\.wg0\}' \
    && fail "temp-backup still hardcodes f0.wg0 default"

# Behavioral: temp-backup default host is inventory when TEMP_BACKUP_* unset.
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home/Documents"
: >"$TEST_ROOT/home/Documents/doc.txt"
cat >"$TEST_ROOT/bin/rsync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\0' "$@" >"${RSYNC_ARGV:?}"
EOF
chmod +x "$TEST_ROOT/bin/rsync"
# basename must exist for temp-backup validation.
export PATH="$TEST_ROOT/bin:/usr/bin:/bin"
export HOME="$TEST_ROOT/home"
export RSYNC_ARGV="$TEST_ROOT/rsync.argv"
unset TEMP_BACKUP_DEST TEMP_BACKUP_HOST BACKUP_DEST || true
"$TEMP_BACKUP" "$HOME/Documents/" >"$TEST_ROOT/out" \
    || fail "temp-backup with inventory default failed"
grep -Fq "Destination: ${F3S_TEMP_BACKUP_HOST}:tempbackup" "$TEST_ROOT/out" \
    || fail "expected inventory default dest: $(cat "$TEST_ROOT/out")"

printf 'f3s-hosts test: ok\n'
