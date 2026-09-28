#!/usr/bin/env fish

set -gx QUICKLOG_HEADLESS 1
source (dirname (status filename))/../conf.d/taskwarrior.fish
source (dirname (status filename))/../conf.d/quicklog.fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
set -e WORKTIME_DIR
set -gx TASK_CALLS "$TEST_ROOT/task-calls"
set -g NOTE_NAME ql-(basename $TEST_ROOT).md
mkdir -p "$HOME/Notes"
touch "$TASK_CALLS"

function remove_test_root --on-event fish_exit
    rm -f "/tmp/$NOTE_NAME"
    rm -rf "$TEST_ROOT"
end

function fail
    echo "quicklog_import: $argv" >&2
    exit 1
end

# Mock only the external task command; exercise both real import consumers,
# their shared parser, and the real jq parser.
function task
    if test "$argv[1]" = status:pending
        switch $EXPORT_MODE
            case task_fail
                printf '[{"description":"already pending"}]\n'
                return 1
            case jq_fail
                # jq emits a plausible partial list before the malformed tail.
                printf '[{"description":"already pending"}]\n{"broken":'
                return 0
            case success
                printf '[{"description":"already pending"}]\n'
                return 0
        end
    else if test "$argv[1]" = add
        string join ' ' -- $argv >>"$TASK_CALLS"
        echo 'Created task 1.'
        return 0
    end
    return 1
end

function expect_no_add
    test (count (cat "$TASK_CALLS")) -eq 0
    or fail "task add ran after failed preload"
    set -q __quicklog_pending
    and fail "failed preload left a pending-task cache"
end

for mode in task_fail jq_fail
    set -g EXPORT_MODE $mode
    printf 'home new task\n' | taskwarrior::quicklog_import_content >/dev/null 2>/dev/null
    and fail "stdin import accepted $mode"
    expect_no_add

    set -l note "$HOME/Notes/$NOTE_NAME"
    printf 'home new task\n' >"$note"
    taskwarrior::quicklogger >/dev/null 2>/dev/null
    and fail "local import accepted $mode"
    test -f "$note"
    or fail "local note was consumed after $mode"
    expect_no_add
end

# A retry with a good preload consumes the local file, skips the pending task,
# and adds repeated new descriptions only once.
set -g EXPORT_MODE success
set -l note "$HOME/Notes/$NOTE_NAME"
printf 'home already pending\nhome new task\nhome new task\n' >"$note"
taskwarrior::quicklogger >/dev/null 2>/dev/null
or fail "local import failed after preload recovered"
test -e "$note"
and fail "successful local import kept the note"
test -f "/tmp/$NOTE_NAME"
or fail "successful local import did not move the note"
test (count (cat "$TASK_CALLS")) -eq 1
or fail "local import did not deduplicate new descriptions"

printf 'home already pending\nhome stdin task\nhome stdin task\n' | taskwarrior::quicklog_import_content >/dev/null 2>/dev/null
or fail "stdin import failed with good preload"
test (count (cat "$TASK_CALLS")) -eq 2
or fail "stdin import did not deduplicate new descriptions"
set -q __quicklog_pending
and fail "successful import left a pending-task cache"

echo 'quicklog_import: ok'
