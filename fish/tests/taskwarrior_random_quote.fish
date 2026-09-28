#!/usr/bin/env fish

set -gx QUICKLOG_HEADLESS 1
source (dirname (status filename))/../conf.d/taskwarrior.fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
mkdir -p "$HOME/Notes/random"
touch "$HOME/Notes/random/Maybe.md" "$HOME/Notes/random/Focus.md"
set -g TASKWARRIOR_MAX_PENDING_RANDOM_TASKS 2

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "taskwarrior_random_quote: $argv" >&2
    exit 1
end

function task
    switch (string join ' ' -- $argv)
        case 'status:pending +maybe count'
            echo $MAYBE_COUNT
        case 'status:pending +random -work count'
            echo $RANDOM_COUNT
        case '*'
            fail "unexpected task call: $argv"
    end
end

# Track creations while exercising random_quote's real slot accounting.
function _taskwarrior::fill_random_slot
    set -ga FILL_CALLS "$argv[1]"
    set -g RANDOM_COUNT (math $RANDOM_COUNT + 1)
    if test "$argv[1]" = "$HOME/Notes/random/Maybe.md"
        set -g MAYBE_COUNT (math $MAYBE_COUNT + 1)
    end
end

function reset_case
    set -g RANDOM_COUNT $argv[1]
    set -g MAYBE_COUNT $argv[2]
    set -g FILL_CALLS
end

# A full set of ordinary random slots still gets one missing maybe task.
reset_case 2 0
taskwarrior::random_quote
test (count $FILL_CALLS) -eq 1
or fail "full slots produced more than the guaranteed maybe task"
test "$FILL_CALLS[1]" = "$HOME/Notes/random/Maybe.md"
or fail "full slots did not replenish Maybe.md"
test $RANDOM_COUNT -eq 3
or fail "full slots ran the ordinary random fill loop"

# The guarantee is idempotent on the next invocation, even above the cap.
taskwarrior::random_quote
test (count $FILL_CALLS) -eq 1
or fail "repeated invocation added another maybe task"

reset_case 2 1
taskwarrior::random_quote
test (count $FILL_CALLS) -eq 0
or fail "full slots with an existing maybe task added a task"

# With one opening, the maybe task occupies it before ordinary filling.
reset_case 1 0
taskwarrior::random_quote
test (count $FILL_CALLS) -eq 1
or fail "one open slot was filled more than once"
test "$FILL_CALLS[1]" = "$HOME/Notes/random/Maybe.md"
or fail "one open slot was not reserved for Maybe.md"
test $RANDOM_COUNT -eq 2
or fail "one open slot exceeded the random cap"

# A present maybe task leaves ordinary random filling unchanged.
reset_case 1 1
taskwarrior::random_quote
test (count $FILL_CALLS) -eq 1
or fail "existing maybe task changed ordinary slot filling"
test $RANDOM_COUNT -eq 2
or fail "ordinary filling exceeded the random cap"

echo 'taskwarrior_random_quote: ok'
