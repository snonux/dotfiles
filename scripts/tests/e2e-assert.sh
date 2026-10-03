#!/usr/bin/env bash
# Unit checks for scripts/lib/e2e-assert.sh (task s33).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r LIB="${SCRIPT_DIR}/../lib/e2e-assert.sh"
declare -r QUICKLOG_E2E_WRAPPER="${SCRIPT_DIR}/../quicklog-drain-e2e"
declare -r QUICKLOG_E2E_COMMON="${SCRIPT_DIR}/../quicklog/e2e/common.sh"
declare -r QUICKLOG_E2E_RUN="${SCRIPT_DIR}/../quicklog/e2e/run"
declare -r TW_E2E="${SCRIPT_DIR}/../taskwarrior-export-e2e"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

die() {
    printf 'e2e-assert test: %s\n' "$*" >&2
    exit 1
}

bash -n "$LIB" || die "bash -n lib failed"
bash -n "$QUICKLOG_E2E_WRAPPER" || die "bash -n quicklog-drain-e2e wrapper failed"
bash -n "$QUICKLOG_E2E_COMMON" || die "bash -n quicklog e2e common.sh failed"
bash -n "$QUICKLOG_E2E_RUN" || die "bash -n quicklog e2e run failed"
bash -n "$TW_E2E" || die "bash -n taskwarrior-export-e2e failed"
shellcheck -x "$LIB" || die "shellcheck lib failed"

# Real source line required (shellcheck source= directive alone must not pass).
_sources_e2e_assert() {
    grep -qE '^[[:space:]]*source[[:space:]].*lib/e2e-assert\.sh' "$1"
}

fixture_comment_only="$TEST_ROOT/comment-only-harness"
cat >"$fixture_comment_only" <<'EOF'
#!/usr/bin/env bash
# shellcheck source=scripts/lib/e2e-assert.sh
echo hello
EOF
if _sources_e2e_assert "$fixture_comment_only"; then
    die "comment-only fixture incorrectly passed structural source check"
fi

# Harnesses must source the shared lib (quicklog via common.sh) and must not
# redefine the assert family.
for harness in "$QUICKLOG_E2E_COMMON" "$TW_E2E"; do
    _sources_e2e_assert "$harness" \
        || die "$(basename "$harness") does not source lib/e2e-assert.sh"
    if grep -nE '^(say|fail|assert_rc|assert_rc_nonzero|assert_eq|assert_contains|assert_not_contains|assert_exists|assert_missing)\(\)' \
        "$harness"; then
        die "$(basename "$harness") still defines local assert helpers"
    fi
done

# Thin wrapper must exec the co-located runner (not hold the suite itself).
grep -q 'quicklog/e2e/run' "$QUICKLOG_E2E_WRAPPER" \
    || die "quicklog-drain-e2e wrapper does not exec quicklog/e2e/run"
if grep -qE '^(say|fail|assert_eq)\(\)' "$QUICKLOG_E2E_WRAPPER"; then
    die "quicklog-drain-e2e wrapper still contains harness body"
fi

# --- Behavioural checks (source in a clean namespace) -----------------------

PROGRAM=e2e-assert-test
FAILURES=0
# shellcheck source=scripts/lib/e2e-assert.sh
source "$LIB"

[[ "$(type -t say)" == function ]] || die "say missing after source"
[[ "$(type -t fail)" == function ]] || die "fail missing after source"
[[ "$(type -t assert_rc)" == function ]] || die "assert_rc missing"
[[ "$(type -t assert_rc_nonzero)" == function ]] || die "assert_rc_nonzero missing"
[[ "$(type -t assert_eq)" == function ]] || die "assert_eq missing"
[[ "$(type -t assert_contains)" == function ]] || die "assert_contains missing"
[[ "$(type -t assert_not_contains)" == function ]] || die "assert_not_contains missing"
[[ "$(type -t assert_exists)" == function ]] || die "assert_exists missing"
[[ "$(type -t assert_missing)" == function ]] || die "assert_missing missing"

# Pass paths — capture stdout via temp files so FAILURES stays in this shell.
assert_eq "equal strings" "a" "a" >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: equal strings" ]] \
    || die "assert_eq pass: $(cat "$TEST_ROOT/out")"
[[ "$FAILURES" -eq 0 ]] || die "FAILURES bumped on assert_eq pass"

assert_rc "zero rc" 0 0 >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: zero rc (rc=0)" ]] \
    || die "assert_rc pass: $(cat "$TEST_ROOT/out")"

assert_rc_nonzero "nonzero" 7 >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: nonzero (rc=7)" ]] \
    || die "assert_rc_nonzero pass: $(cat "$TEST_ROOT/out")"

assert_contains "needle in hay" "hello world" "world" >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: needle in hay" ]] \
    || die "assert_contains pass: $(cat "$TEST_ROOT/out")"

assert_not_contains "no needle" "hello" "xyz" >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: no needle" ]] \
    || die "assert_not_contains pass: $(cat "$TEST_ROOT/out")"

: >"$TEST_ROOT/present"
assert_exists "file present" "$TEST_ROOT/present" >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: file present ($TEST_ROOT/present)" ]] \
    || die "assert_exists pass: $(cat "$TEST_ROOT/out")"

assert_missing "file absent" "$TEST_ROOT/absent" >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == "ok: file absent ($TEST_ROOT/absent)" ]] \
    || die "assert_missing pass: $(cat "$TEST_ROOT/out")"

say "phase label" >"$TEST_ROOT/out"
[[ "$(cat "$TEST_ROOT/out")" == $'\n== phase label ==' ]] \
    || die "say format: $(cat -A "$TEST_ROOT/out")"

# Fail paths (must increment FAILURES, not exit)
assert_eq "mismatch" "got" "want" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 1 ]] || die "assert_eq fail did not bump FAILURES (got $FAILURES)"
grep -Fq "e2e-assert-test: FAIL: mismatch: got 'got', expected 'want'" \
    "$TEST_ROOT/err" || die "assert_eq fail message: $(cat "$TEST_ROOT/err")"

assert_rc "bad rc" 0 1 >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 2 ]] || die "assert_rc fail FAILURES=$FAILURES"
grep -Fq "expected rc=0, got rc=1" "$TEST_ROOT/err" \
    || die "assert_rc fail msg: $(cat "$TEST_ROOT/err")"

assert_rc_nonzero "should fail" 0 >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 3 ]] || die "assert_rc_nonzero fail FAILURES=$FAILURES"
grep -Fq "expected a nonzero exit code" "$TEST_ROOT/err" \
    || die "assert_rc_nonzero fail msg: $(cat "$TEST_ROOT/err")"

assert_contains "missing needle" "hay" "needle" \
    >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 4 ]] || die "assert_contains fail FAILURES=$FAILURES"
grep -Fq "e2e-assert-test: FAIL: missing needle: 'hay' does not contain 'needle'" \
    "$TEST_ROOT/err" || die "assert_contains fail msg: $(cat "$TEST_ROOT/err")"

assert_not_contains "has needle" "haystack" "hay" \
    >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 5 ]] || die "assert_not_contains fail FAILURES=$FAILURES"
grep -Fq "e2e-assert-test: FAIL: has needle: 'haystack' unexpectedly contains 'hay'" \
    "$TEST_ROOT/err" || die "assert_not_contains fail msg: $(cat "$TEST_ROOT/err")"

assert_exists "gone" "$TEST_ROOT/absent" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 6 ]] || die "assert_exists fail FAILURES=$FAILURES"
grep -Fq "is missing" "$TEST_ROOT/err" \
    || die "assert_exists fail msg: $(cat "$TEST_ROOT/err")"

assert_missing "still there" "$TEST_ROOT/present" \
    >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 7 ]] || die "assert_missing fail FAILURES=$FAILURES"
grep -Fq "exists but must not" "$TEST_ROOT/err" \
    || die "assert_missing fail msg: $(cat "$TEST_ROOT/err")"

# Call the lib fail (sourced above); do not shadow with die.
fail "direct fail call" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || true
[[ "$FAILURES" -eq 8 ]] || die "direct fail FAILURES=$FAILURES"
[[ "$(cat "$TEST_ROOT/err")" == "e2e-assert-test: FAIL: direct fail call" ]] \
    || die "direct fail msg: $(cat "$TEST_ROOT/err")"

printf 'ok: e2e-assert unit checks passed (%d expected failures exercised)\n' \
    "$FAILURES"
