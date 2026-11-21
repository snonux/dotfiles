#!/usr/bin/env bash
# Checks for scripts/audit-due bootstrap (task gg4): a repo without any audit
# marker must be skipped with a message, not abort the whole run, so repos
# later in glob order still get tagged. Uses throwaway repos under mktemp
# only; never touches ~/git (bootstrap creates real git tags).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r AUDIT_DUE="${SCRIPT_DIR}/../audit-due"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'audit-due test: %s\n' "$*" >&2
    exit 1
}

# Isolate git from the user's global config (signing, hooks, identity) and
# pin the commit date so the expected audit/<date> tag name is known.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid
export GIT_AUTHOR_DATE='2026-01-15T12:00:00Z'
export GIT_COMMITTER_DATE='2026-01-15T12:00:00Z'
declare -r WANT_TAG='audit/2026-01-15'

# make_repo NAME COMMIT_MESSAGE: one-commit repo under $TEST_ROOT/repos.
make_repo() {
    local -r dir="$TEST_ROOT/repos/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q
    printf '%s\n' "$1" >"$dir/file.txt"
    git -C "$dir" add file.txt
    git -C "$dir" commit -q -m "$2"
}

bash -n "$AUDIT_DUE" || fail "bash -n failed"

# a-plain sorts first and has no audit marker; b-audited has a keyword commit.
make_repo a-plain 'init'
make_repo b-audited 'code audit fixes'

# --- Positive: unmarked repo is skipped, later repo still gets tagged ---
declare -i rc=0
"$AUDIT_DUE" bootstrap "$TEST_ROOT/repos" >"$TEST_ROOT/out1" 2>&1 || rc=$?
((rc == 0)) || fail "bootstrap exited $rc: $(cat "$TEST_ROOT/out1")"
grep -Fq 'a-plain: no audit marker found, skipping' "$TEST_ROOT/out1" \
    || fail "missing skip line for a-plain: $(cat "$TEST_ROOT/out1")"
grep -Fq "b-audited: tagged" "$TEST_ROOT/out1" \
    || fail "missing tagged line for b-audited: $(cat "$TEST_ROOT/out1")"
git -C "$TEST_ROOT/repos/b-audited" rev-parse -q --verify \
    "refs/tags/$WANT_TAG" >/dev/null \
    || fail "b-audited has no $WANT_TAG tag"
if [[ -n "$(git -C "$TEST_ROOT/repos/a-plain" tag -l 'audit/*')" ]]; then
    fail "a-plain was tagged although it has no audit marker"
fi

# --- Negative: second run reports the existing tag, creates nothing new ---
rc=0
"$AUDIT_DUE" bootstrap "$TEST_ROOT/repos" >"$TEST_ROOT/out2" 2>&1 || rc=$?
((rc == 0)) || fail "second bootstrap exited $rc: $(cat "$TEST_ROOT/out2")"
grep -Fq "b-audited: tag $WANT_TAG already exists" "$TEST_ROOT/out2" \
    || fail "missing 'already exists' line: $(cat "$TEST_ROOT/out2")"
[[ "$(git -C "$TEST_ROOT/repos/b-audited" tag -l 'audit/*' | wc -l)" -eq 1 ]] \
    || fail "second run created extra audit tags"

printf 'audit-due test: ok\n'
