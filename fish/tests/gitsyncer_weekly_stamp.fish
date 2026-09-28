#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
set -gx GITSYNCER_TEST_CALLS "$TEST_ROOT/calls"
mkdir -p "$HOME"

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "gitsyncer_weekly_stamp: $argv" >&2
    exit 1
end

source (dirname (status filename))/../conf.d/supersync.fish
or fail "could not source supersync"

set -l enable_file "$HOME/.gitsyncer_enable"
set -l gitsyncer "$HOME/go/bin/gitsyncer"
echo 0 >"$enable_file"

supersync::gitsyncer
and fail "missing binary succeeded"
test (cat "$enable_file") = 0
or fail "missing binary changed the weekly stamp"

mkdir -p (dirname "$gitsyncer")
printf '%s\n' \
    '#!/usr/bin/env sh' \
    'printf "%s\n" "$1" >> "$GITSYNCER_TEST_CALLS"' \
    'if [ "$GITSYNCER_TEST_MODE" = sync_fail ] && [ "$1" = sync ]; then exit 1; fi' \
    'if [ "$GITSYNCER_TEST_MODE" = showcase_fail ] && [ "$1" = showcase ]; then exit 1; fi' \
    >"$gitsyncer"
chmod +x "$gitsyncer"

set -gx GITSYNCER_TEST_MODE success
: >"$enable_file"
: >"$GITSYNCER_TEST_CALLS"
supersync::gitsyncer
or fail "empty enable file did not run the initial sync"
test (cat "$enable_file") -gt 0
or fail "initial sync did not advance the weekly stamp"
test (count (cat "$GITSYNCER_TEST_CALLS")) -eq 2
or fail "initial sync did not run both commands"
echo 0 >"$enable_file"

function date
    return 1
end
supersync::gitsyncer
and fail "failed timestamp lookup succeeded"
functions -e date
test (cat "$enable_file") = 0
or fail "failed timestamp lookup changed the weekly stamp"

function cat
    if test "$argv[1]" = "$HOME/.gitsyncer_enable"
        return 1
    end
    command cat $argv
end
supersync::gitsyncer
and fail "failed stamp read succeeded"
functions -e cat
test (cat "$enable_file") = 0
or fail "failed stamp read changed the weekly stamp"

function math
    return 1
end
supersync::gitsyncer
and fail "failed weekly interval calculation succeeded"
functions -e math
test (cat "$enable_file") = 0
or fail "failed weekly interval calculation changed the stamp"

function math
    if test "$argv[1]" != 7
        return 1
    end
    builtin math $argv
end
supersync::gitsyncer
and fail "failed elapsed-time calculation succeeded"
functions -e math
test (cat "$enable_file") = 0
or fail "failed elapsed-time calculation changed the weekly stamp"

echo invalid >"$enable_file"
supersync::gitsyncer
and fail "invalid weekly stamp succeeded"
echo 0 >"$enable_file"

for mode in sync_fail showcase_fail
    set -gx GITSYNCER_TEST_MODE $mode
    echo 0 >"$enable_file"
    : >"$GITSYNCER_TEST_CALLS"
    supersync::gitsyncer
    and fail "$mode succeeded"
    test (cat "$enable_file") = 0
    or fail "$mode changed the weekly stamp"
    set -l expected_calls 2
    if test $mode = sync_fail
        set expected_calls 1
    end
    test (count (cat "$GITSYNCER_TEST_CALLS")) -eq $expected_calls
    or fail "$mode ran an unexpected number of commands"
end

set -gx GITSYNCER_TEST_MODE success
echo 0 >"$enable_file"
: >"$GITSYNCER_TEST_CALLS"
supersync::gitsyncer
or fail "successful sync and showcase failed"
test (cat "$enable_file") -gt 0
or fail "successful sync and showcase did not advance the stamp"
test (count (cat "$GITSYNCER_TEST_CALLS")) -eq 2
or fail "successful run did not call both commands"

supersync::gitsyncer
or fail "recent stamp check failed"
test (count (cat "$GITSYNCER_TEST_CALLS")) -eq 2
or fail "recent stamp did not prevent another run"

echo 'gitsyncer_weekly_stamp: ok'
