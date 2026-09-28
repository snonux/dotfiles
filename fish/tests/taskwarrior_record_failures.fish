#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
set -gx QUICKLOG_HEADLESS 1
set -gx GOS_DIR "$TEST_ROOT/gos"
set -gx WORKTIME_DIR "$TEST_ROOT/worktime"
set -gx DELETE_LOG "$TEST_ROOT/deleted"
set -gx MODIFY_LOG "$TEST_ROOT/modified"
mkdir -p "$HOME/Notes/random" "$HOME/Notes/Bulgarian" "$GOS_DIR" "$WORKTIME_DIR"
touch "$DELETE_LOG" "$MODIFY_LOG"

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "taskwarrior_record_failures: $argv" >&2
    exit 1
end

source (dirname (status filename))/../conf.d/taskwarrior.fish
or fail "could not source taskwarrior"

set -g MOCK_FAIL_FIRST 1
set -g SHARE_JSON (jq -nc '[{description:"good share",tags:["share","li"]}]')
set -g MAY_JSON (jq -nc '[{uuid:"may-good",project:"home",description:"good maybe"}]')
set -g WIN_JSON (jq -nc '[{uuid:"win-good",description:"good win"}]')
set -g ADD_JSON (jq -nc '[{project:"home",description:"good add"}]')
set -g BD_JSON (jq -nc '[{uuid:"bd-good",description:"good bd"}]')

function task
    if test "$argv[-1]" = delete
        echo "$MOCK_MODE:$argv[1]" >>"$DELETE_LOG"
        return 0
    end
    switch "$MOCK_MODE"
        case unscheduled
            if test "$argv[-1]" = _ids
                printf '%s\n' bad good
                return 0
            end
        case gos
            if test "$argv[1]" = +share
                printf '%s\n' bad good
                return 0
            end
            if test "$argv[-1]" = export
                if test "$argv[1]" = bad -a "$MOCK_FAIL_FIRST" = 1
                    return 7
                end
                echo "$SHARE_JSON"
                return 0
            end
        case maybe
            if test "$argv[-1]" = export
                if test "$argv[1]" = +m -a "$MOCK_FAIL_FIRST" = 1
                    return 7
                end
                if test "$argv[1]" = +maybe
                    echo '[]'
                else
                    echo "$MAY_JSON"
                end
                return 0
            end
        case wins
            if test "$argv[-1]" = export
                if test "$argv[1]" = +win -a "$MOCK_FAIL_FIRST" = 1
                    return 7
                end
                echo "$WIN_JSON"
                return 0
            end
        case add
            if test "$argv[-1]" = _uuids
                printf '%s\n' bad good
                return 0
            end
            if test "$argv[-1]" = export
                if test "$argv[1]" = bad -a "$MOCK_FAIL_FIRST" = 1
                    return 7
                end
                echo "$ADD_JSON"
                return 0
            end
        case bd
            if test "$argv[1]" = +bd -a "$argv[-1]" = export
                if test "$MOCK_FAIL_FIRST" = 1
                    return 7
                end
                echo "$BD_JSON"
                return 0
            end
        case random
            if test "$argv[-1]" = count
                echo 0
                return 0
            end
    end
    echo "unexpected task call: $MOCK_MODE $argv" >&2
    return 99
end

function timeout
    echo "$argv[4]" >>"$MODIFY_LOG"
    if test "$argv[4]" = bad -a "$MOCK_FAIL_FIRST" = 1
        return 7
    end
    return 0
end

set -g MOCK_MODE unscheduled
taskwarrior::unscheduled
and fail "failed first due-date modify reported success"
test (string join , (cat "$MODIFY_LOG")) = bad,good
or fail "failed due-date modify skipped the later task"
set -g MOCK_FAIL_FIRST 0
taskwarrior::unscheduled
or fail "successful due-date modifies failed"

set -g MOCK_MODE gos
set -g MOCK_FAIL_FIRST 1
taskwarrior::gos_queue &>/dev/null
and fail "failed first share export reported success"
contains -- gos:good (cat "$DELETE_LOG")
or fail "failed share export skipped the later share"
contains -- gos:bad (cat "$DELETE_LOG")
and fail "failed share export deleted its task"
set -g MOCK_FAIL_FIRST 0
taskwarrior::gos_queue &>/dev/null
or fail "successful share retry failed"
contains -- gos:bad (cat "$DELETE_LOG")
or fail "successful share retry did not delete its task"

set -g MOCK_MODE maybe
set -g MOCK_FAIL_FIRST 1
echo '* existing' >"$HOME/Notes/random/Maybe.md"
taskwarrior::export::maybe &>/dev/null
and fail "failed first maybe export reported success"
contains -- maybe:may-good (cat "$DELETE_LOG")
or fail "failed maybe export skipped the later tag"
string match -q '*good maybe*' (cat "$HOME/Notes/random/Maybe.md")
or fail "successful later maybe record was not written"
set -g MOCK_FAIL_FIRST 0
taskwarrior::export::maybe &>/dev/null
or fail "successful maybe retry failed"
echo '* baseline maybe' >"$HOME/Notes/random/Maybe.md"
set -l deletes_before (count (cat "$DELETE_LOG"))
chmod 000 "$HOME/Notes/random/Maybe.md"
taskwarrior::export::maybe &>/dev/null
and fail "unreadable maybe note reported success"
chmod 600 "$HOME/Notes/random/Maybe.md"
test (cat "$HOME/Notes/random/Maybe.md") = '* baseline maybe'
or fail "unreadable maybe note was replaced"
test (count (cat "$DELETE_LOG")) -eq $deletes_before
or fail "unreadable maybe note deleted a task"

set -g MOCK_MODE wins
set -g MOCK_FAIL_FIRST 1
echo '* existing' >"$HOME/Notes/random/Wins.md"
taskwarrior::export::wins &>/dev/null
and fail "failed first win export reported success"
contains -- wins:win-good (cat "$DELETE_LOG")
or fail "failed win export skipped the later tag"
set -g MOCK_FAIL_FIRST 0
taskwarrior::export::wins &>/dev/null
or fail "successful win retry failed"
echo '* baseline win' >"$HOME/Notes/random/Wins.md"
set deletes_before (count (cat "$DELETE_LOG"))
chmod 000 "$HOME/Notes/random/Wins.md"
taskwarrior::export::wins &>/dev/null
and fail "unreadable wins note reported success"
chmod 600 "$HOME/Notes/random/Wins.md"
test (cat "$HOME/Notes/random/Wins.md") = '* baseline win'
or fail "unreadable wins note was replaced"
test (count (cat "$DELETE_LOG")) -eq $deletes_before
or fail "unreadable wins note deleted a task"

set -g MOCK_MODE add
set -g MOCK_FAIL_FIRST 1
taskwarrior::export::add &>/dev/null
and fail "failed first add export reported success"
contains -- add:good (cat "$DELETE_LOG")
or fail "failed add export skipped the later task"
contains -- add:bad (cat "$DELETE_LOG")
and fail "failed add export deleted its task"
set -g MOCK_FAIL_FIRST 0
taskwarrior::export::add &>/dev/null
or fail "successful add retry failed"
contains -- add:bad (cat "$DELETE_LOG")
or fail "successful add retry did not delete its task"

set -g MOCK_MODE bd
set -g MOCK_FAIL_FIRST 1
taskwarrior::export::bd &>/dev/null
and fail "failed Bulgarian export reported success"
contains -- bd:bd-good (cat "$DELETE_LOG")
and fail "failed Bulgarian export deleted its task"
set -g MOCK_FAIL_FIRST 0
taskwarrior::export::bd &>/dev/null
or fail "successful Bulgarian retry failed"
contains -- bd:bd-good (cat "$DELETE_LOG")
or fail "successful Bulgarian retry did not delete its task"

set -g MOCK_MODE random
set -g MOCK_FAIL_FIRST 1
set -g RANDOM_CALLS 0
set -g TASKWARRIOR_MAX_PENDING_RANDOM_TASKS 1
function taskwarrior::random_count
    echo 0
end
function _taskwarrior::fill_random_slot
    set -g RANDOM_CALLS (math $RANDOM_CALLS + 1)
    if test $RANDOM_CALLS -eq 1 -a $MOCK_FAIL_FIRST -eq 1
        return 7
    end
    return 0
end
taskwarrior::random_quote
and fail "failed first random quote slot reported success"
test $RANDOM_CALLS -eq 2
or fail "failed random quote slot skipped the later slot"
set -g MOCK_FAIL_FIRST 0
taskwarrior::random_quote
or fail "successful random quote retry failed"

source (dirname (status filename))/../conf.d/quicklog.fish
or fail "could not source quicklog"
function _taskwarrior::quicklog_load_pending
    return 0
end
function _taskwarrior::quicklog_import_line
    return 0
end
set -g MOVE_FAIL 1
set -l ql_file "$HOME/Notes/ql-test"
echo 'test quicklog' >"$ql_file"
function mv
    if test $MOVE_FAIL -eq 1
        return 7
    end
    command mv "$argv[1]" "$TEST_ROOT/moved"
end
taskwarrior::quicklogger &>/dev/null
and fail "failed Quicklog move reported success"
test -f "$ql_file"
or fail "failed Quicklog move consumed its source"
set -g MOVE_FAIL 0
taskwarrior::quicklogger &>/dev/null
or fail "successful Quicklog retry failed"
test -f "$TEST_ROOT/moved"
or fail "successful Quicklog retry did not move its source"

set -l unreadable "$HOME/Notes/ql-unreadable"
echo 'unreadable quicklog' >"$unreadable"
chmod 000 "$unreadable"
taskwarrior::quicklogger &>/dev/null
and fail "unreadable Quicklog file reported success"
test -f "$unreadable"
or fail "unreadable Quicklog file was moved without importing"
chmod 600 "$unreadable"
taskwarrior::quicklogger &>/dev/null
or fail "readable Quicklog retry failed"
test (cat "$TEST_ROOT/moved") = 'unreadable quicklog'
or fail "readable Quicklog retry did not move the file"

echo 'taskwarrior_record_failures: ok'
