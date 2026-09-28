#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
set -gx SUPERSYNC_TEST_CALLS "$TEST_ROOT/calls"
mkdir -p "$HOME/go/bin"

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "supersync_daily_stamp: $argv" >&2
    exit 1
end

source (dirname (status filename))/../conf.d/supersync.fish
or fail "could not source supersync"

function record_step
    echo $argv[1] >>"$SUPERSYNC_TEST_CALLS"
    test "$SUPERSYNC_TEST_FAIL" != "$argv[1]"
end

function worktime::supersync
    record_step worktime
end

function supersync::prompts
    record_step prompts
end

function snonux::sync
    record_step snonux
end

function supersync::gitsyncer
    record_step gitsyncer
end

function tmputils::clean
    record_step clean
end

function update::tools
    record_step update
end

printf '%s\n' \
    '#!/usr/bin/env sh' \
    'echo gos >> "$SUPERSYNC_TEST_CALLS"' \
    'test "$SUPERSYNC_TEST_FAIL" != gos' \
    >"$HOME/go/bin/gos"
chmod +x "$HOME/go/bin/gos"
touch "$HOME/go/bin/snonux" "$HOME/.gos_enable"

set -l expected_calls 'worktime,prompts,gos,snonux,gitsyncer,clean,update'
for step in worktime prompts gos snonux gitsyncer clean update
    set -gx SUPERSYNC_TEST_FAIL $step
    echo 123 >"$SUPERSYNC_STAMP_FILE"
    : >"$SUPERSYNC_TEST_CALLS"

    supersync
    and fail "$step failure reported success"
    test (cat "$SUPERSYNC_STAMP_FILE") = 123
    or fail "$step failure advanced the daily stamp"
    test (string join , (cat "$SUPERSYNC_TEST_CALLS")) = "$expected_calls"
    or fail "$step failure skipped a later step"
end

rm "$SUPERSYNC_STAMP_FILE"
set -gx SUPERSYNC_TEST_FAIL update
supersync
and fail "failure without an existing stamp reported success"
test ! -e "$SUPERSYNC_STAMP_FILE"
or fail "failure without an existing stamp wrote one"

set -gx SUPERSYNC_TEST_FAIL none
echo 123 >"$SUPERSYNC_STAMP_FILE"
supersync
or fail "successful run failed"
test (cat "$SUPERSYNC_STAMP_FILE") -gt 123
or fail "successful run did not advance the daily stamp"

echo 123 >"$SUPERSYNC_STAMP_FILE"
function mv
    return 1
end
supersync
and fail "stamp rename failure reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "stamp rename failure changed the daily stamp"
functions -e mv

function date
    return 1
end
supersync
and fail "timestamp failure reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "timestamp failure changed the daily stamp"
functions -e date

echo 'supersync_daily_stamp: ok'
