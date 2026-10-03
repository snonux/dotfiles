#!/usr/bin/env bash
# Negative/repro checks for scripts/wol-f3s Shelly home resolution (task m33).
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

# Structural guard: privileged helper must never eval SUDO_USER/DOAS_USER.
if grep -Eq 'eval[[:space:]]+echo[[:space:]]+"~' "$WOL_F3S"; then
    fail "wol-f3s still uses eval for tilde/home expansion"
fi
if grep -Eq '^[[:space:]]*eval[[:space:]]' "$WOL_F3S"; then
    fail "wol-f3s still contains eval"
fi

# Fixture passwd: local-account layout used on Fedora earth / NetBSD Pis.
declare -r PASSWD_FIXTURE="$TEST_ROOT/passwd"
cat >"$PASSWD_FIXTURE" <<'EOF'
root:x:0:0:root:/root:/bin/sh
alice:x:1000:1000:Alice:/home/alice:/bin/sh
bob:x:1001:1001:Bob:/srv/bob:/bin/sh
EOF

# Repro of the pre-fix form: crafted "username" runs during eval tilde expand.
declare -r PWNED="$TEST_ROOT/pwned"
declare -r EVIL_USER='alice$(touch '"$PWNED"')'
rm -f "$PWNED"
# shellcheck disable=SC2086 # intentional unquoted eval repro of the old bug
eval echo "~${EVIL_USER}" >/dev/null
[[ -e "$PWNED" ]] || fail "buggy eval repro did not create side-effect file"
rm -f "$PWNED"

# Source helpers only (main is gated on BASH_SOURCE).
export _PASSWD_FILE="$PASSWD_FIXTURE"
# shellcheck source=scripts/wol-f3s
source "$WOL_F3S"

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
if _user_home_from_passwd nobody 2>/dev/null; then
    fail "unknown user nobody unexpectedly resolved"
fi

# _shelly_pass_file uses SUDO_USER/DOAS_USER and falls back to HOME.
unset SUDO_USER DOAS_USER || true
export HOME="$TEST_ROOT/fallback-home"
mkdir -p "$HOME"
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

printf 'wol-f3s test: ok\n'
