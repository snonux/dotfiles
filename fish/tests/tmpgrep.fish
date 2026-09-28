#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
mkdir -p "$HOME"

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "tmpgrep: $argv" >&2
    exit 1
end

source (dirname (status filename))/../conf.d/tmputils.fish >/dev/null
or fail "could not source tmputils"

set -l sample "$TMPUTILS_DIR/sample file"
printf 'first line\nNeedle here\nlast line\n' >"$sample"
or fail "could not create sample"

tmpgrep 'sample file' -i -n -- needle >"$TEST_ROOT/actual"
or fail "matching grep failed"
printf '2:Needle here\n' >"$TEST_ROOT/expected"
diff -u "$TEST_ROOT/expected" "$TEST_ROOT/actual"
or fail "grep arguments or output were changed"

tmpgrep 'sample file' -q -- absent >"$TEST_ROOT/actual"
set -l grep_status $status
test "$grep_status" -eq 1
or fail "nonmatching grep returned status $grep_status instead of 1"
test ! -s "$TEST_ROOT/actual"
or fail "nonmatching grep produced output"

echo 'tmpgrep: ok'
