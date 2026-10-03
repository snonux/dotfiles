#!/usr/bin/env bash
# Checks for scripts/wol-f3s: Shelly home resolution (m33), mute/wake/ssh
# fail-closed messaging under set -e (n33), and w33 shutdown_fleet DRY +
# pinned known_hosts — without undoing m33/n33 ops semantics.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r WOL_F3S="${SCRIPT_DIR}/../wol-f3s"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'wol-f3s test: %s\n' "$*" >&2
    exit 1
}

bash -n "$WOL_F3S" || fail "bash -n failed"
# SC2029 (info) on intentional client-side expand of GOGIOS_MUTE_FILE is
# pre-existing; require warning+ so new issues still fail the test.
shellcheck -x -S warning "$WOL_F3S" || fail "shellcheck failed"

# n33: portable shebang + strict mode (may already be present from m33).
head -n 20 "$WOL_F3S" | grep -Eq '^#!/usr/bin/env bash$' \
    || fail "missing #!/usr/bin/env bash shebang"
grep -Eq '^set -euo pipefail$' "$WOL_F3S" \
    || fail "missing set -euo pipefail"

# Structural guard: privileged helper must never eval SUDO_USER/DOAS_USER.
if grep -Eq 'eval[[:space:]]+echo[[:space:]]+"~' "$WOL_F3S"; then
    fail "wol-f3s still uses eval for tilde/home expansion"
fi
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$WOL_F3S"; then
    fail "wol-f3s still contains eval"
fi

# n33 / m33 ops semantics: mute must not abort privileged shutdown; all-path
# wake failures must not skip remaining wakes / unmute.
# Strip comments so a doc line alone cannot satisfy the guard.
code_no_comments="$(sed -E 's/[[:space:]]+#.*//' "$WOL_F3S")"
# w33: shared shutdown_fleet owns mute || true; both CLI paths must call it.
shutdown_fleet_body="$(awk '
    /^shutdown_fleet\(\)/ { inblk=1; next }
    inblk && /^main\(\)/ { exit }
    inblk && /^[[:space:]]*[^#]/ { print }
' "$WOL_F3S" | sed -E 's/[[:space:]]+#.*//')"
grep -Eq '^[[:space:]]*mute_gogios[[:space:]]*\|\|[[:space:]]*true[[:space:]]*$' \
    <<<"$shutdown_fleet_body" \
    || fail "shutdown_fleet must call mute_gogios || true (not comment-only)"
shutdown_case="$(awk '
    /^[[:space:]]*shutdown\|poweroff\|down\)/ { inblk=1; next }
    inblk && /^[[:space:]]*shutdown-/ { exit }
    inblk && /^[[:space:]]*[^#]/ { print }
' "$WOL_F3S" | sed -E 's/[[:space:]]+#.*//')"
grep -Eq '^[[:space:]]*shutdown_fleet([[:space:]]|$)' <<<"$shutdown_case" \
    || fail "shutdown case must call shutdown_fleet"
grep -Eq 'shutdown_fleet[[:space:]]+--with-pis' <<<"$shutdown_case" \
    && fail "shutdown case must not pass --with-pis"
shutdown_all_case="$(awk '
    /^[[:space:]]*shutdown-all\)/ { inblk=1; next }
    inblk && /^[[:space:]]*\*\)/ { exit }
    inblk && /^[[:space:]]*[^#]/ { print }
' "$WOL_F3S" | sed -E 's/[[:space:]]+#.*//')"
grep -Eq '^[[:space:]]*shutdown_fleet[[:space:]]+--with-pis' \
    <<<"$shutdown_all_case" \
    || fail "shutdown-all case must call shutdown_fleet --with-pis"
# All-path tracks wake_failed rather than bare || true; either is fine as long
# as a failed wake does not abort before later wakes / unmute.
grep -Eq 'wake "f0".*(\|\| true|\|\| wake_failed=1)' <<<"$code_no_comments" \
    || fail "all-path wake f0 must not abort on failure"
grep -Eq 'wake "f1".*(\|\| true|\|\| wake_failed=1)' <<<"$code_no_comments" \
    || fail "all-path wake f1 must not abort on failure"
grep -Eq 'wake "f2".*(\|\| true|\|\| wake_failed=1)' <<<"$code_no_comments" \
    || fail "all-path wake f2 must not abort on failure"
grep -Eq 'unmute_gogios[[:space:]]*\|\|[[:space:]]*true' <<<"$code_no_comments" \
    || fail "all-path must keep unmute_gogios || true"

# w33: pin known_hosts; never disable host-key checks for power control.
# Drop full-line and trailing comments before scanning for insecure options.
ssh_opts_code="$(grep -Ev '^[[:space:]]*#' "$WOL_F3S" | sed -E 's/[[:space:]]+#.*//')"
declare -r WOL_KNOWN_HOSTS="${SCRIPT_DIR}/../wol-f3s.known_hosts"
[[ -f "$WOL_KNOWN_HOSTS" ]] || fail "missing pinned known_hosts: $WOL_KNOWN_HOSTS"
grep -Eq 'StrictHostKeyChecking=no|UserKnownHostsFile=/dev/null' \
    <<<"$ssh_opts_code" \
    && fail "wol-f3s must not disable host-key checking"
grep -Fq 'StrictHostKeyChecking=yes' <<<"$ssh_opts_code" \
    || fail "SSH options must set StrictHostKeyChecking=yes"
grep -Eq '_WOL_F3S_KNOWN_HOSTS:=.*/wol-f3s\.known_hosts' <<<"$ssh_opts_code" \
    || fail "default known_hosts pin must be wol-f3s.known_hosts beside the script"
grep -Eq 'UserKnownHostsFile=\$\{_WOL_F3S_KNOWN_HOSTS\}|UserKnownHostsFile="\$\{_WOL_F3S_KNOWN_HOSTS\}"' \
    <<<"$ssh_opts_code" \
    || fail "SSH options must pin UserKnownHostsFile via _WOL_F3S_KNOWN_HOSTS"
# Pin file must cover Beelinks, Pis, and Gogios gateways (port 2).
for host in 192.168.1.130 192.168.1.131 192.168.1.132 192.168.1.133 \
    192.168.1.125 192.168.1.126 192.168.1.127 192.168.1.128; do
    grep -Eq "^${host//./\\.}[[:space:]]" "$WOL_KNOWN_HOSTS" \
        || fail "known_hosts missing host key for $host"
done
grep -Fq '[blowfish.buetow.org]:2' "$WOL_KNOWN_HOSTS" \
    || fail "known_hosts missing blowfish gateway key"
grep -Fq '[fishfinger.buetow.org]:2' "$WOL_KNOWN_HOSTS" \
    || fail "known_hosts missing fishfinger gateway key"

# Single-host wake must still abort on failure (no || true / wake_failed).
single_wake_block="$(awk '
    /^[[:space:]]*f0\)/ { inblk=1 }
    inblk && /wake "f0"/ { print; exit }
' "$WOL_F3S")"
[[ "$single_wake_block" == *'wake "f0"'* ]] \
    || fail "could not locate single-host f0 wake"
[[ "$single_wake_block" != *'||'* ]] \
    || fail "single-host f0 wake must propagate failure (no || true)"

# Helpers must surface clear failure text (fail-closed messaging).
grep -Fq 'Failed to mute Gogios' "$WOL_F3S" \
    || fail "mute_gogios missing clear failure message"
grep -Fq 'Failed to send WoL packet' "$WOL_F3S" \
    || fail "wake missing clear failure message"
grep -Fq 'Failed to un-mute Gogios' "$WOL_F3S" \
    || fail "unmute_gogios missing clear failure message"
# mute/unmute SSH must use BatchMode and a short ConnectTimeout together.
grep -E 'BatchMode=yes.*ConnectTimeout=5|ConnectTimeout=5.*BatchMode=yes' \
    "$WOL_F3S" | grep -Eq 'BatchMode=yes' \
    || fail "mute/unmute SSH should use BatchMode=yes and ConnectTimeout=5"
# Explicit ConnectTimeout assert (value used by mute/unmute/shutdown SSH).
grep -Fq 'ConnectTimeout=5' "$WOL_F3S" \
    || fail "SSH helpers must set ConnectTimeout=5"
# Partial WoL on all-path must not print the unconditional success banner alone.
grep -Fq 'WoL incomplete' "$WOL_F3S" \
    || fail "all-path must report WoL incomplete when wake_failed"

# Fixture passwd: local-account layout used on Fedora earth / NetBSD Pis.
# Includes empty-home, truncated, and no-trailing-NL rows for rejection /
# last-line coverage.
declare -r PASSWD_FIXTURE="$TEST_ROOT/passwd"
{
    cat <<'EOF'
root:x:0:0:root:/root:/bin/sh
alice:x:1000:1000:Alice:/home/alice:/bin/sh
bob:x:1001:1001:Bob:/srv/bob:/bin/sh
emptyhome:x:1002:1002:Empty::/bin/sh
truncated:x:1003
toofew:x:1004:1004
EOF
    # Last entry deliberately has no trailing newline.
    printf '%s' 'nolf:x:1005:1005:NoLF:/home/nolf:/bin/sh'
} >"$PASSWD_FIXTURE"

# Repro of the pre-fix form: crafted "username" runs during eval tilde expand.
declare -r PWNED="$TEST_ROOT/pwned"
declare -r EVIL_USER='alice$(touch '"$PWNED"')'
rm -f "$PWNED"
# shellcheck disable=SC2086 # intentional unquoted eval repro of the old bug
eval echo "~${EVIL_USER}" >/dev/null
[[ -e "$PWNED" ]] || fail "buggy eval repro did not create side-effect file"
rm -f "$PWNED"

# Eager SHELLY_PASS_FILE: evil SUDO_USER must be rejected at source time and
# the global used by shelly_set must fall back to HOME (not only later calls).
export _PASSWD_FILE="$PASSWD_FIXTURE"
export HOME="$TEST_ROOT/fallback-home"
mkdir -p "$HOME"
export SUDO_USER="$EVIL_USER"
unset DOAS_USER || true
# shellcheck source=scripts/wol-f3s
source "$WOL_F3S"
[[ "$SHELLY_PASS_FILE" == "$HOME/.shelly_plug" ]] || fail \
    "source-time SHELLY_PASS_FILE=${SHELLY_PASS_FILE@Q}, want fallback ${HOME@Q}/.shelly_plug"
[[ -e "$PWNED" ]] && fail "evil SUDO_USER created side-effect file at source"

# Fixed path: same crafted username must be rejected (no side effects).
if _user_home_from_passwd "$EVIL_USER" 2>/dev/null; then
    fail "crafted username with \$(...) was accepted"
fi
[[ -e "$PWNED" ]] && fail "side-effect file created after safe resolver"

# More negative cases: metacharacters, path traversal, whitespace, empty.
for bad in 'alice;id' 'alice|id' 'alice`id`' 'alice and bob' '../alice'; do
    if _user_home_from_passwd "$bad" 2>/dev/null; then
        fail "accepted invalid username: ${bad@Q}"
    fi
done
if _user_home_from_passwd '' 2>/dev/null; then
    fail "accepted empty username"
fi

# Positive: valid local users resolve from the fixture passwd file.
got="$(_user_home_from_passwd alice)" || fail "alice lookup failed"
[[ "$got" == /home/alice ]] || fail "alice home=${got@Q}, want /home/alice"
got="$(_user_home_from_passwd bob)" || fail "bob lookup failed"
[[ "$got" == /srv/bob ]] || fail "bob home=${got@Q}, want /srv/bob"
# Last line without trailing newline must still resolve.
got="$(_user_home_from_passwd nolf)" || fail "nolf (no trailing NL) lookup failed"
[[ "$got" == /home/nolf ]] || fail "nolf home=${got@Q}, want /home/nolf"
if _user_home_from_passwd nobody 2>/dev/null; then
    fail "unknown user nobody unexpectedly resolved"
fi

# Empty home field and truncated/malformed rows reject safely.
if _user_home_from_passwd emptyhome 2>/dev/null; then
    fail "empty home field was accepted"
fi
if _user_home_from_passwd truncated 2>/dev/null; then
    fail "truncated passwd row was accepted"
fi
if _user_home_from_passwd toofew 2>/dev/null; then
    fail "too-few-fields passwd row was accepted"
fi

# _shelly_pass_file uses SUDO_USER/DOAS_USER and falls back to HOME.
unset SUDO_USER DOAS_USER || true
got="$(_shelly_pass_file)"
[[ "$got" == "$HOME/.shelly_plug" ]] || fail \
    "fallback path=${got@Q}, want ${HOME@Q}/.shelly_plug"

export SUDO_USER=alice
got="$(_shelly_pass_file)"
[[ "$got" == /home/alice/.shelly_plug ]] || fail \
    "SUDO_USER path=${got@Q}, want /home/alice/.shelly_plug"

unset SUDO_USER
export DOAS_USER=bob
got="$(_shelly_pass_file)"
[[ "$got" == /srv/bob/.shelly_plug ]] || fail \
    "DOAS_USER path=${got@Q}, want /srv/bob/.shelly_plug"

# Crafted SUDO_USER must not run code and must fall back to HOME.
export SUDO_USER="$EVIL_USER"
got="$(_shelly_pass_file)"
[[ "$got" == "$HOME/.shelly_plug" ]] || fail \
    "evil SUDO_USER path=${got@Q}, want fallback ${HOME@Q}/.shelly_plug"
[[ -e "$PWNED" ]] && fail "evil SUDO_USER created side-effect file"

# Empty home in passwd → reject → HOME fallback via _shelly_pass_file.
export SUDO_USER=emptyhome
got="$(_shelly_pass_file)"
[[ "$got" == "$HOME/.shelly_plug" ]] || fail \
    "empty-home SUDO_USER path=${got@Q}, want fallback ${HOME@Q}/.shelly_plug"

# Truncated passwd row → reject → HOME fallback.
export SUDO_USER=truncated
got="$(_shelly_pass_file)"
[[ "$got" == "$HOME/.shelly_plug" ]] || fail \
    "truncated SUDO_USER path=${got@Q}, want fallback ${HOME@Q}/.shelly_plug"

# --- n33: mute_gogios / wake failure reporting (fake ssh / wol on PATH) ---
declare -r FAKE_BIN="$TEST_ROOT/fakebin"
mkdir -p "$FAKE_BIN"
declare -r SSH_LOG="$TEST_ROOT/ssh.log"
declare -r WOL_LOG="$TEST_ROOT/wol.log"
: >"$SSH_LOG"
: >"$WOL_LOG"

# Fake ssh: succeed for blowfish, fail for fishfinger; log every target.
cat >"$FAKE_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="${SSH_LOG:?}"
target=""
for arg in "$@"; do
    case "$arg" in
        rex@*) target="${arg#rex@}" ;;
    esac
done
printf '%s\n' "$target" >>"$log"
if [[ "$target" == *fishfinger* ]]; then
    exit 1
fi
exit 0
EOF
chmod +x "$FAKE_BIN/ssh"

# Fake wol: fail for a sentinel MAC, succeed otherwise.
cat >"$FAKE_BIN/wol" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${WOL_LOG:?}"
for arg in "$@"; do
    if [[ "$arg" == "aa:bb:cc:dd:ee:ff" ]]; then
        exit 1
    fi
done
exit 0
EOF
chmod +x "$FAKE_BIN/wol"

export PATH="$FAKE_BIN:$PATH"
export SSH_LOG WOL_LOG

# mute_gogios must try every gateway, print a clear error, and return 1 when
# any SSH fails — without leaving the second gateway unattempted.
: >"$SSH_LOG"
mute_out="$(mute_gogios 2>&1)" && mute_ec=0 || mute_ec=$?
(( mute_ec != 0 )) || fail "mute_gogios should return non-zero when a gateway fails"
grep -Fq 'Failed to mute Gogios' <<<"$mute_out" \
    || fail "mute_gogios stderr/stdout missing failure text: ${mute_out@Q}"
# Both gateways attempted (order preserved from GOGIOS_GATEWAYS).
mapfile -t ssh_targets <"$SSH_LOG"
(( ${#ssh_targets[@]} == 2 )) \
    || fail "mute_gogios attempted ${#ssh_targets[@]} gateway(s), want 2"
[[ "${ssh_targets[0]}" == *blowfish* ]] \
    || fail "first mute target unexpected: ${ssh_targets[0]@Q}"
[[ "${ssh_targets[1]}" == *fishfinger* ]] \
    || fail "second mute target unexpected: ${ssh_targets[1]@Q}"

# Fail-first gateway ordering: first gateway fails, second still attempted.
cat >"$FAKE_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="${SSH_LOG:?}"
target=""
for arg in "$@"; do
    case "$arg" in
        rex@*) target="${arg#rex@}" ;;
    esac
done
printf '%s\n' "$target" >>"$log"
if [[ "$target" == *blowfish* ]]; then
    exit 1
fi
exit 0
EOF
chmod +x "$FAKE_BIN/ssh"
: >"$SSH_LOG"
mute_ff_out="$(mute_gogios 2>&1)" && mute_ff_ec=0 || mute_ff_ec=$?
(( mute_ff_ec != 0 )) || fail "mute_gogios should fail when first gateway fails"
grep -Fq 'Failed to mute Gogios' <<<"$mute_ff_out" \
    || fail "fail-first mute missing failure text: ${mute_ff_out@Q}"
mapfile -t ssh_targets <"$SSH_LOG"
(( ${#ssh_targets[@]} == 2 )) \
    || fail "fail-first mute attempted ${#ssh_targets[@]} gateway(s), want 2"
[[ "${ssh_targets[0]}" == *blowfish* ]] \
    || fail "fail-first first target unexpected: ${ssh_targets[0]@Q}"
[[ "${ssh_targets[1]}" == *fishfinger* ]] \
    || fail "fail-first second target unexpected: ${ssh_targets[1]@Q}"

# Restore second-gateway-fails ssh for later unmute helper check.
cat >"$FAKE_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="${SSH_LOG:?}"
target=""
for arg in "$@"; do
    case "$arg" in
        rex@*) target="${arg#rex@}" ;;
    esac
done
printf '%s\n' "$target" >>"$log"
if [[ "$target" == *fishfinger* ]]; then
    exit 1
fi
exit 0
EOF
chmod +x "$FAKE_BIN/ssh"

# wake: clear failure message + non-zero on wol failure.
wake_out="$(wake "f0" "aa:bb:cc:dd:ee:ff" 2>&1)" && wake_ec=0 || wake_ec=$?
(( wake_ec != 0 )) || fail "wake should return non-zero when wol fails"
grep -Fq 'Failed to send WoL packet' <<<"$wake_out" \
    || fail "wake missing failure text: ${wake_out@Q}"

# wake success path still reports clearly.
wake_ok="$(wake "f0" "e8:ff:1e:d7:1c:ac" 2>&1)" || fail "wake success unexpectedly failed"
grep -Fq 'WoL packet sent' <<<"$wake_ok" \
    || fail "wake success missing confirmation: ${wake_ok@Q}"

# unmute_gogios SSH failures: skip the k3s wait by forcing pending=0 path.
# Override ping to always succeed and keep a short timeout.
cat >"$FAKE_BIN/ping" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_BIN/ping"
GOGIOS_UNMUTE_TIMEOUT=1
: >"$SSH_LOG"
unmute_out="$(unmute_gogios 2>&1)" && unmute_ec=0 || unmute_ec=$?
(( unmute_ec != 0 )) || fail "unmute_gogios should return non-zero when SSH fails"
grep -Fq 'Failed to un-mute Gogios' <<<"$unmute_out" \
    || fail "unmute_gogios missing failure text: ${unmute_out@Q}"
mapfile -t ssh_targets <"$SSH_LOG"
(( ${#ssh_targets[@]} == 2 )) \
    || fail "unmute_gogios attempted ${#ssh_targets[@]} gateway(s), want 2"

# --- n33: behavioural main-path ops semantics with fakes ---
declare -r MAIN_SHUTDOWN_LOG="$TEST_ROOT/main-shutdown.log"
declare -r MAIN_WAKE_LOG="$TEST_ROOT/main-wake.log"
declare -r MAIN_UNMUTE_LOG="$TEST_ROOT/main-unmute.log"
: >"$MAIN_SHUTDOWN_LOG"
: >"$MAIN_WAKE_LOG"
: >"$MAIN_UNMUTE_LOG"

# Mute failure must not abort privileged shutdown: still reaches host shutdown.
umount_nfs_mounts() { return 0; }
shelly_set() { return 0; }
shutdown_bhyve_host() {
    printf '%s\n' "$1" >>"$MAIN_SHUTDOWN_LOG"
    return 0
}
# Fail-first mute (blowfish fails) via existing GOGIOS_GATEWAYS + ssh fake below.
cat >"$FAKE_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
log="${SSH_LOG:?}"
target=""
for arg in "$@"; do
    case "$arg" in
        rex@*) target="${arg#rex@}" ;;
    esac
done
printf '%s\n' "$target" >>"$log"
if [[ "$target" == *blowfish* ]]; then
    exit 1
fi
exit 0
EOF
chmod +x "$FAKE_BIN/ssh"
: >"$SSH_LOG"
: >"$MAIN_SHUTDOWN_LOG"
main_shut_out="$(main shutdown 2>&1)" && main_shut_ec=0 || main_shut_ec=$?
(( main_shut_ec == 0 )) || fail "main shutdown exited $main_shut_ec after mute failure: ${main_shut_out@Q}"
mapfile -t shut_hosts <"$MAIN_SHUTDOWN_LOG"
(( ${#shut_hosts[@]} == 3 )) \
    || fail "mute failure skipped host shutdown; got ${#shut_hosts[@]} host(s)"
[[ "${shut_hosts[0]}" == f0 && "${shut_hosts[1]}" == f1 && "${shut_hosts[2]}" == f2 ]] \
    || fail "shutdown host order unexpected: ${shut_hosts[*]@Q}"
# Mute still tried both gateways before continuing.
mapfile -t ssh_targets <"$SSH_LOG"
(( ${#ssh_targets[@]} == 2 )) \
    || fail "main shutdown mute attempted ${#ssh_targets[@]} gateway(s), want 2"
grep -Fq 'Shutdown commands sent to all Beelinks' <<<"$main_shut_out" \
    || fail "main shutdown missing Beelink success banner: ${main_shut_out@Q}"

# w33: shutdown-all shares shutdown_fleet --with-pis (mute || true + Pis).
declare -r MAIN_PI_LOG="$TEST_ROOT/main-pi.log"
: >"$MAIN_PI_LOG"
: >"$MAIN_SHUTDOWN_LOG"
: >"$SSH_LOG"
shutdown_host() {
    printf '%s\n' "$1" >>"$MAIN_PI_LOG"
    return 0
}
main_all_shut_out="$(main shutdown-all 2>&1)" && main_all_shut_ec=0 || main_all_shut_ec=$?
(( main_all_shut_ec == 0 )) \
    || fail "main shutdown-all exited $main_all_shut_ec after mute failure: ${main_all_shut_out@Q}"
mapfile -t shut_hosts <"$MAIN_SHUTDOWN_LOG"
(( ${#shut_hosts[@]} == 3 )) \
    || fail "shutdown-all skipped Beelinks; got ${#shut_hosts[@]} host(s)"
mapfile -t pi_hosts <"$MAIN_PI_LOG"
(( ${#pi_hosts[@]} == 4 )) \
    || fail "shutdown-all skipped Pis; got ${#pi_hosts[@]} pi(s)"
[[ "${pi_hosts[*]}" == "pi0 pi1 pi2 pi3" ]] \
    || fail "shutdown-all pi order unexpected: ${pi_hosts[*]@Q}"
mapfile -t ssh_targets <"$SSH_LOG"
(( ${#ssh_targets[@]} == 2 )) \
    || fail "main shutdown-all mute attempted ${#ssh_targets[@]} gateway(s), want 2"
grep -Fq 'Shutdown commands sent to all machines' <<<"$main_all_shut_out" \
    || fail "main shutdown-all missing machines banner: ${main_all_shut_out@Q}"

# f0 wake failure must still run f1/f2 + unmute; no unconditional success banner.
wake() {
    local name=$1
    local mac=$2
    printf '%s\n' "$name" >>"$MAIN_WAKE_LOG"
    if [[ "$name" == f0 ]]; then
        echo "  ✗ Failed to send WoL packet to $name ($mac)" >&2
        return 1
    fi
    echo "  ✓ WoL packet sent to $name"
    return 0
}
unmute_gogios() {
    printf 'unmuted\n' >>"$MAIN_UNMUTE_LOG"
    return 1
}
: >"$MAIN_WAKE_LOG"
: >"$MAIN_UNMUTE_LOG"
main_wake_out="$(main all 2>&1)" && main_wake_ec=0 || main_wake_ec=$?
(( main_wake_ec != 0 )) || fail "main all should exit non-zero when a wake fails"
grep -Fq 'WoL incomplete' <<<"$main_wake_out" \
    || fail "main all missing incomplete summary: ${main_wake_out@Q}"
grep -Fq 'WoL packets sent. Machines should boot' <<<"$main_wake_out" \
    && fail "main all printed unconditional success after wake failure"
mapfile -t wake_hosts <"$MAIN_WAKE_LOG"
(( ${#wake_hosts[@]} == 3 )) \
    || fail "f0 wake failure skipped later wakes; got ${#wake_hosts[@]} wake(s)"
[[ "${wake_hosts[0]}" == f0 && "${wake_hosts[1]}" == f1 && "${wake_hosts[2]}" == f2 ]] \
    || fail "wake host order unexpected: ${wake_hosts[*]@Q}"
[[ -s "$MAIN_UNMUTE_LOG" ]] || fail "f0 wake failure skipped unmute_gogios"

printf 'wol-f3s test: ok\n'
