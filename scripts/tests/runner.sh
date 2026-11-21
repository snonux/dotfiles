#!/usr/bin/env bash
# Checks for scripts/tests/run, the single test entry point (task mg4).
#
# Builds throwaway scripts/ trees under mktemp with dummy tests, stub e2e
# harnesses and small scripts to lint, then runs the runner against them.
# The runner must pass a clean tree and exit non-zero when any one check
# fails, while still running (and reporting) the remaining checks. It must
# never launch the production-touching quicklog-drain-e2e.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -r SCRIPT_DIR
declare -r RUNNER="${SCRIPT_DIR}/run"
TEST_ROOT="$(mktemp -d)"
declare -r TEST_ROOT

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

fail() {
    printf 'runner test: %s\n' "$*" >&2
    exit 1
}

# write_script PATH BODY: an executable bash script with BODY after the
# shebang. Used for dummy tests and stub e2e harnesses alike.
write_script() {
    local -r path="$1" body="$2"
    mkdir -p "$(dirname "$path")"
    printf '#!/usr/bin/env bash\n%s\n' "$body" >"$path"
    chmod +x "$path"
}

# make_tree DIR: a scripts/ tree on which every check passes.
make_tree() {
    local -r dir="$1/scripts"
    local entry
    write_script "$dir/tests/ok.sh" 'exit 0'
    printf 'exit 0\n' >"$dir/tests/ok.rb"
    for entry in dedup-e2e stabilize-video-e2e taskwarrior-export-e2e \
        quicklog/e2e/protocol-fake; do
        write_script "$dir/$entry" 'exit 0'
    done
    # Must never run: it stands in for the live-S3 suite.
    write_script "$dir/quicklog-drain-e2e" \
        "touch '$1/production-touched'"
    mkdir -p "$dir/lib"
    # The $ in these generated scripts must stay literal (SC2016).
    # shellcheck disable=SC2016
    printf '# shellcheck shell=bash\nlib_ok() { printf "%%s\\n" "$1"; }\n' \
        >"$dir/lib/ok.sh"
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env zsh\necho $unquoted\n' >"$dir/zsh-helper"
}

# run_runner DIR: run the runner on DIR/scripts; sets OUT and RC.
run_runner() {
    RC=0
    OUT="$(bash "$RUNNER" "$1/scripts" 2>&1)" || RC=$?
}

assert_out() {
    grep -qF -- "$1" <<<"$OUT" || fail "$2: missing '$1' in output:
$OUT"
}

test_clean_tree_passes() {
    # The hidden parent mimics a .claude/worktrees checkout: only hidden
    # names inside scripts/ may be skipped, not the path leading to it.
    local -r t="$TEST_ROOT/.hidden-parent/clean"
    make_tree "$t"
    run_runner "$t"
    (( RC == 0 )) || fail "clean tree: exit $RC, want 0:
$OUT"
    assert_out 'PASS  test  scripts/tests/ok.sh' 'clean tree'
    assert_out 'PASS  test  scripts/tests/ok.rb' 'clean tree'
    assert_out 'PASS  e2e   scripts/quicklog/e2e/protocol-fake' 'clean tree'
    assert_out 'PASS  lint  scripts/lib/ok.sh' 'clean tree'
    assert_out ' 0 failed' 'clean tree'
    # zsh scripts are not shellchecked (shellcheck has no zsh dialect).
    if grep -qF 'zsh-helper' <<<"$OUT"; then
        fail "clean tree: zsh script was linted:
$OUT"
    fi
    [[ ! -e "$t/production-touched" ]] \
        || fail 'clean tree: quicklog-drain-e2e (live S3) was run'
}

# Each case breaks one thing; the runner must exit non-zero, name the
# broken check, and still report the other checks.
test_failing_unit_test() {
    local -r t="$TEST_ROOT/bad-unit"
    make_tree "$t"
    write_script "$t/scripts/tests/bad.sh" 'echo broken >&2; exit 3'
    run_runner "$t"
    (( RC != 0 )) || fail "failing test: exit 0, want non-zero:
$OUT"
    assert_out 'FAIL  test  scripts/tests/bad.sh' 'failing test'
    assert_out '| broken' 'failing test'
    assert_out 'PASS  lint  scripts/lib/ok.sh' 'failing test'
    assert_out ' 1 failed' 'failing test'
}

test_failing_ruby_test() {
    local -r t="$TEST_ROOT/bad-ruby"
    make_tree "$t"
    printf 'exit 2\n' >"$t/scripts/tests/bad.rb"
    run_runner "$t"
    (( RC != 0 )) || fail 'failing ruby test: exit 0, want non-zero'
    assert_out 'FAIL  test  scripts/tests/bad.rb' 'failing ruby test'
}

test_missing_e2e() {
    local -r t="$TEST_ROOT/missing-e2e"
    make_tree "$t"
    rm "$t/scripts/dedup-e2e"
    run_runner "$t"
    (( RC != 0 )) || fail 'missing e2e: exit 0, want non-zero'
    assert_out 'FAIL  e2e   dedup-e2e (missing)' 'missing e2e'
}

test_shellcheck_finding() {
    local -r t="$TEST_ROOT/lint"
    make_tree "$t"
    # shellcheck disable=SC2016 # the unquoted $1 is the finding under test
    write_script "$t/scripts/sloppy" 'rm -rf $1/tmp'
    run_runner "$t"
    (( RC != 0 )) || fail 'shellcheck finding: exit 0, want non-zero'
    assert_out 'FAIL  lint  scripts/sloppy' 'shellcheck finding'
    assert_out 'SC2086' 'shellcheck finding'
}

# The real scripts/.shellcheckrc must make the runner flag a function
# called under 'if' (set -e suppressed, SC2310), and the real
# tests/.shellcheckrc must keep that optional check off for tests.
test_set_e_suppressed_rc() {
    local -r t="$TEST_ROOT/rc"
    # shellcheck disable=SC2016 # the $ belongs to the generated script
    local -r body='set -euo pipefail
check() { [[ -n "${1:-}" ]]; }
if check "$@"; then echo yes; fi'
    make_tree "$t"
    cp -- "$SCRIPT_DIR/../.shellcheckrc" "$t/scripts/.shellcheckrc"
    cp -- "$SCRIPT_DIR/.shellcheckrc" "$t/scripts/tests/.shellcheckrc"
    write_script "$t/scripts/uses-predicate" "$body"
    write_script "$t/scripts/tests/uses-predicate.sh" "$body"
    run_runner "$t"
    (( RC != 0 )) || fail 'rc: unsuppressed SC2310 site passed:
'"$OUT"
    assert_out 'FAIL  lint  scripts/uses-predicate' 'rc'
    assert_out 'SC2310' 'rc'
    assert_out 'PASS  lint  scripts/tests/uses-predicate.sh' 'rc'
}

test_clean_tree_passes
test_set_e_suppressed_rc
test_failing_unit_test
test_failing_ruby_test
test_missing_e2e
test_shellcheck_finding
printf 'runner test: all checks passed\n'
