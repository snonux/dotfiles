#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home with spaces"
set -gx TEST_CALLS "$TEST_ROOT/calls"
set -gx REAL_GIT (command -s git)
mkdir -p "$HOME" "$TEST_ROOT/bin" "$TEST_ROOT/caller with spaces"
or exit 1

function remove_test_root --on-event fish_exit
    command rm -rf "$TEST_ROOT"
end

function fail
    echo "worktime_sync: $argv" >&2
    exit 1
end

# Every git invocation, including find's subprocesses, stays inside this stub.
printf '%s\n' \
    '#!/usr/bin/env sh' \
    'printf "%s|%s\n" "$PWD" "$*" >> "$TEST_CALLS"' \
    'if [ "$TEST_LOCAL_GIT" = 1 ]; then' \
    '    case "$1" in add|diff|commit) exec "$REAL_GIT" "$@" ;; esac' \
    'fi' \
    'if [ "$1" = "$TEST_FAIL" ]; then exit 17; fi' \
    'if [ "$1" = diff ]; then exit "$TEST_DIFF_STATUS"; fi' \
    'exit 0' >"$TEST_ROOT/bin/git"
chmod +x "$TEST_ROOT/bin/git"
set -gx PATH "$TEST_ROOT/bin" $PATH
set -gx TEST_DIFF_STATUS 1
set -gx TEST_FAIL none

source (dirname (status filename))/../conf.d/worktime.fish
or fail "could not source worktime"

function tasksync
    printf '%s|tasksync\n' "$PWD" >>"$TEST_CALLS"
    test "$TEST_FAIL" != tasksync
end

function find
    printf '%s|find\n' "$PWD" >>"$TEST_CALLS"
    if test "$TEST_FAIL" = find
        return 17
    end
    command find $argv
end

function assert_calls
    set -l actual
    for entry in (cat "$TEST_CALLS")
        set -l fields (string split '|' -- "$entry")
        test "$fields[1]" = "$WORKTIME_DIR"
        or fail "operation escaped worktime: $entry"
        set -a actual "$fields[2]"
    end
    test (string join , -- $actual) = "$argv[1]"
    or fail "unexpected operations: "(string join , -- $actual)
end

function run_sync
    : >"$TEST_CALLS"
    worktime::sync &>/dev/null
    set -l sync_status $status
    test "$PWD" = "$TEST_ROOT/caller with spaces"
    or fail "sync did not restore caller directory"
    return $sync_status
end

cd "$TEST_ROOT/caller with spaces"
touch "$HOME/.tasksync_enable"
run_sync
and fail "missing worktime directory succeeded"
test ! -s "$TEST_CALLS"
or fail "missing directory ran task, find or git operations"

mkdir -p "$WORKTIME_DIR"
echo '{}' >"$WORKTIME_DIR/host with spaces.jsonl"
# Also exercise a failed cd when the path exists (e.g. access failure).
function cd
    if test "$argv[1]" = "$WORKTIME_DIR"
        return 17
    end
    builtin cd $argv
end
run_sync
and fail "failed directory change succeeded"
test ! -s "$TEST_CALLS"
or fail "failed directory change ran operations"
functions -e cd

for step in tasksync find add diff commit pull push
    set -gx TEST_FAIL $step
    run_sync
    and fail "$step failure reported success"
    switch $step
        case tasksync
            assert_calls tasksync
        case find
            assert_calls tasksync,find
        case add
            assert_calls 'tasksync,find,add ./host with spaces.jsonl'
        case diff
            assert_calls 'tasksync,find,add ./host with spaces.jsonl,diff --quiet HEAD'
        case commit
            assert_calls 'tasksync,find,add ./host with spaces.jsonl,diff --quiet HEAD,commit -a -m sync'
        case pull
            assert_calls 'tasksync,find,add ./host with spaces.jsonl,diff --quiet HEAD,commit -a -m sync,pull'
        case push
            assert_calls 'tasksync,find,add ./host with spaces.jsonl,diff --quiet HEAD,commit -a -m sync,pull,push'
    end
end

set -gx TEST_FAIL none
run_sync
or fail "successful sync failed"
assert_calls 'tasksync,find,add ./host with spaces.jsonl,diff --quiet HEAD,commit -a -m sync,pull,push'

set -gx TEST_DIFF_STATUS 0
run_sync
or fail "unchanged repository failed"
assert_calls 'tasksync,find,add ./host with spaces.jsonl,diff --quiet HEAD,pull,push'

rm "$HOME/.tasksync_enable"
run_sync
or fail "sync without tasksync failed"
assert_calls 'find,add ./host with spaces.jsonl,diff --quiet HEAD,pull,push'

# Restoring the caller is itself a meaningful failure.
function cd
    if test "$argv[1]" = "$TEST_ROOT/caller with spaces"
        return 17
    end
    builtin cd $argv
end
: >"$TEST_CALLS"
worktime::sync &>/dev/null
and fail "failed directory restoration reported success"
functions -e cd
cd "$TEST_ROOT/caller with spaces"

# Verify staging and committing against real Git in a disposable repository;
# pull and push remain stubs, so this fixture has no remote at all.
set -gx WORKTIME_DIR "$TEST_ROOT/local git with spaces"
command "$REAL_GIT" init -q -b master "$WORKTIME_DIR"
or fail "could not initialize local Git fixture"
command "$REAL_GIT" -C "$WORKTIME_DIR" config user.name Test
command "$REAL_GIT" -C "$WORKTIME_DIR" config user.email test@example.invalid
command "$REAL_GIT" -C "$WORKTIME_DIR" config commit.gpgsign false
echo initial >"$WORKTIME_DIR/README"
command "$REAL_GIT" -C "$WORKTIME_DIR" add README
command "$REAL_GIT" -C "$WORKTIME_DIR" commit -qm initial
or fail "could not seed local Git fixture"
set -l initial_head (command "$REAL_GIT" -C "$WORKTIME_DIR" rev-parse HEAD)
echo '{}' >"$WORKTIME_DIR/new host with spaces.jsonl"
set -gx TEST_LOCAL_GIT 1
run_sync
or fail "sync of newly created JSONL failed"
assert_calls 'find,add ./new host with spaces.jsonl,diff --quiet HEAD,commit -a -m sync,pull,push'
test (command "$REAL_GIT" -C "$WORKTIME_DIR" rev-parse HEAD) != "$initial_head"
or fail "new JSONL did not create a commit"
test (command "$REAL_GIT" -C "$WORKTIME_DIR" show 'HEAD:new host with spaces.jsonl') = '{}'
or fail "new JSONL was not committed intact"
run_sync
or fail "real unchanged repository failed"
assert_calls 'find,add ./new host with spaces.jsonl,diff --quiet HEAD,pull,push'

echo 'worktime_sync: ok'
