#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
set -gx REAL_GIT (command -s git)
set -gx TEST_CALLS "$TEST_ROOT/calls"
mkdir -p "$HOME/git/worktime" "$TEST_ROOT/bin"
printf '%s\n' '[init]' 'defaultBranch = master' >"$HOME/.gitconfig"

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "supersync_helper_failures: $argv" >&2
    exit 1
end

command git init --bare -q -b master "$TEST_ROOT/remote.git"
or fail "could not initialize remote"
command git -C "$HOME/git/worktime" init -q -b master
or fail "could not initialize worktime"
command git -C "$HOME/git/worktime" config user.name Test
command git -C "$HOME/git/worktime" config user.email test@example.invalid
echo initial >"$HOME/git/worktime/README"
command git -C "$HOME/git/worktime" add README
command git -C "$HOME/git/worktime" commit -qm initial
command git -C "$HOME/git/worktime" remote add origin "$TEST_ROOT/remote.git"
command git -C "$HOME/git/worktime" push -q -u origin master
or fail "could not seed remote"

source (dirname (status filename))/../conf.d/worktime.fish
or fail "could not source worktime"
source (dirname (status filename))/../conf.d/tmputils.fish >/dev/null
or fail "could not source tmputils"
source (dirname (status filename))/../conf.d/update.fish
or fail "could not source update"
source (dirname (status filename))/../conf.d/supersync.fish
or fail "could not source supersync"

function taskwarrior::invoke
    echo invoke >>"$TEST_ROOT/worktime_calls"
    return 0
end
function worktime::uprecords::darwin::collect
    echo collect >>"$TEST_ROOT/worktime_calls"
    return 0
end
function worktime::uprecords::darwin::import
    echo import >>"$TEST_ROOT/worktime_calls"
    return 0
end

function update::tools
    return 0
end

mkdir -p "$HOME/Notes/HabitsAndQuotes" "$HOME/Notes/random"
echo '* productivity' >"$HOME/Notes/random/Productivity.md"
echo '* exercise' >"$HOME/Notes/random/Exercise.md"
echo 'original wisdom' >"$WORKTIME_DIR/work-wisdoms.md"
echo 'original exercises' >"$WORKTIME_DIR/exercises.md"
command git -C "$WORKTIME_DIR" add work-wisdoms.md exercises.md
command git -C "$WORKTIME_DIR" commit -qm 'seed quote files'
command git -C "$WORKTIME_DIR" push -q origin master
set -l quote_baseline (command git -C "$WORKTIME_DIR" rev-parse HEAD)
worktime::supersync_sync sync_quotes &>/dev/null
and fail "missing quote source reported success"
test (cat "$WORKTIME_DIR/work-wisdoms.md") = 'original wisdom'
or fail "missing quote source replaced existing wisdom"
test (cat "$WORKTIME_DIR/exercises.md") = 'original exercises'
or fail "missing quote source replaced existing exercises"
test (command git -C "$WORKTIME_DIR" rev-parse HEAD) = "$quote_baseline"
or fail "missing quote source created a local commit"
test (command git --git-dir="$TEST_ROOT/remote.git" rev-parse master) = "$quote_baseline"
or fail "missing quote source pushed changes"
test (count (command find "$WORKTIME_DIR" -maxdepth 1 -name '.worktime-quotes.*')) -eq 0
or fail "failed quote generation left temporary files"
echo '* mentoring' >"$HOME/Notes/random/Mentoring.md"
: >"$TEST_ROOT/worktime_calls"
function mv
    if test "$argv[2]" = exercises.md
        return 7
    end
    command mv $argv
end
worktime::supersync &>/dev/null
and fail "failed exercises install reported success"
functions -e mv
test (command git -C "$WORKTIME_DIR" rev-parse HEAD) = "$quote_baseline"
or fail "second worktime sync committed partial quote output"
test (command git --git-dir="$TEST_ROOT/remote.git" rev-parse master) = "$quote_baseline"
or fail "second worktime sync pushed partial quote output"
test (string join , (cat "$TEST_ROOT/worktime_calls")) = invoke,collect,import
or fail "first worktime sync failure skipped independent helpers"
worktime::supersync_sync sync_quotes &>/dev/null
or fail "valid quote sources did not sync"
string match -q '*mentoring*' (cat "$WORKTIME_DIR/work-wisdoms.md")
or fail "successful quote sync omitted mentoring"
string match -q '*productivity*' (cat "$WORKTIME_DIR/work-wisdoms.md")
or fail "successful quote sync omitted productivity"
test (cat "$WORKTIME_DIR/exercises.md") = '* exercise'
or fail "successful quote sync omitted exercise"
set -l quote_success_commit (command git -C "$WORKTIME_DIR" rev-parse HEAD)
test "$quote_success_commit" != "$quote_baseline"
or fail "successful quote sync did not commit"
test (command git --git-dir="$TEST_ROOT/remote.git" rev-parse master) = "$quote_success_commit"
or fail "successful quote sync did not push"
rmdir "$HOME/Notes/HabitsAndQuotes"

supersync &>/dev/null
or fail "clean worktime repository should sync successfully"
test -s "$SUPERSYNC_STAMP_FILE"
or fail "successful sync did not write the daily stamp"

printf '%s\n' \
    '#!/usr/bin/env sh' \
    'if [ "$1" = pull ]; then echo pull >> "$TEST_ROOT/pulls"; fi' \
    'if [ "$1" = push ]; then echo push >> "$TEST_ROOT/pushes"; fi' \
    'if [ "$1" = pull ] && [ "$TEST_FAIL" = first_pull ] && [ ! -e "$TEST_ROOT/pull_failed" ]; then' \
    '    touch "$TEST_ROOT/pull_failed"' \
    '    exit 17' \
    'fi' \
    'exec "$REAL_GIT" "$@"' \
    >"$TEST_ROOT/bin/git"
chmod +x "$TEST_ROOT/bin/git"
set -gx PATH "$TEST_ROOT/bin" $PATH

echo 123 >"$SUPERSYNC_STAMP_FILE"
set -gx TEST_FAIL first_pull
supersync >/dev/null 2>&1
and fail "failed first worktime pull reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "failed first worktime pull advanced the daily stamp"
test -e "$TEST_ROOT/pull_failed"
or fail "the first worktime pull was not exercised"
test (count (cat "$TEST_ROOT/pulls")) -eq 1
or fail "a failed first worktime pull reached the second sync"
test ! -e "$TEST_ROOT/pushes"
or fail "a failed first worktime pull was followed by a push"

set -gx TEST_FAIL none
mkdir -p "$TMPUTILS_DIR/stale"
echo old >"$TMPUTILS_DIR/stale/file"
touch -d '40 days ago' "$TMPUTILS_DIR/stale/file"
function mv
    if string match -q '*/OLD/*' -- $argv[2]
        return 1
    end
    command mv $argv
end
supersync >/dev/null 2>&1
and fail "failed cleanup move reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "failed cleanup move advanced the daily stamp"
functions -e mv

mkdir "$TMPUTILS_DIR/bulk"
function find
    if test "$argv[1]" = "$TMPUTILS_DIR/bulk"
        seq 100000
    else
        command find $argv
    end
end
tmputils::clean &>/dev/null
or fail "large mtime scan failed"
test -d "$TMPUTILS_DIR/OLD/bulk."(date +%Y%m%d)
or fail "large mtime scan did not move the stale folder"
functions -e find

printf '%s\n' \
    '#!/usr/bin/env sh' \
    'printf "%s\n" "$*" >> "$TEST_CALLS"' \
    'if [ "$TEST_FAIL" = go ] && [ "$1" = install ] && [ "$2" = mvdan.cc/gofumpt@latest ]; then exit 5; fi' \
    'exit 0' \
    >"$TEST_ROOT/bin/go"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' >"$TEST_ROOT/bin/cursor-agent"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' >"$TEST_ROOT/bin/claude"
printf '%s\n' \
    '#!/usr/bin/env sh' \
    'if [ "$TEST_FAIL" = doas ] && [ "$4" = @openai/codex ]; then exit 9; fi' \
    'exit 0' \
    >"$TEST_ROOT/bin/doas"
chmod +x "$TEST_ROOT/bin/go" "$TEST_ROOT/bin/cursor-agent" "$TEST_ROOT/bin/claude" "$TEST_ROOT/bin/doas"
functions -e update::tools
source (dirname (status filename))/../conf.d/update.fish
or fail "could not restore update::tools"

set -gx TEST_FAIL go
: >"$TEST_CALLS"
supersync >/dev/null 2>&1
and fail "failed background go install reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "failed background go install advanced the daily stamp"
test (count (cat "$TEST_CALLS")) -gt 1
or fail "background failure prevented other updates"

set -gx TEST_FAIL doas
supersync >/dev/null 2>&1
and fail "failed synchronous update reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "failed synchronous update advanced the daily stamp"

set -gx TEST_FAIL none
supersync >/dev/null 2>&1
or fail "successful integration run failed"
test (cat "$SUPERSYNC_STAMP_FILE") -gt 123
or fail "successful integration run did not advance the daily stamp"

set -gx QUICKLOG_HEADLESS 1
source (dirname (status filename))/../conf.d/taskwarrior.fish
or fail "could not source taskwarrior"

printf '%s\n' \
    '#!/usr/bin/env sh' \
    'for arg in "$@"; do' \
    '    if [ "$arg" = count ]; then echo 1; exit 0; fi' \
    '    if [ "$arg" = export ] && [ "$TASK_MODE" = export_fail ]; then exit 7; fi' \
    '    if [ "$arg" = import ] && [ "$TASK_MODE" = import_fail ]; then exit 7; fi' \
    '    if [ "$arg" = delete ]; then echo deleted >> "$TEST_CALLS"; exit 0; fi' \
    'done' \
    'exit 0' \
    >"$TEST_ROOT/bin/task"
chmod +x "$TEST_ROOT/bin/task"
set -gx TASK_MODE export_fail
: >"$TEST_CALLS"
_taskwarrior::export_tag work 123 &>/dev/null
and fail "failed task export was masked"
test ! -s "$TEST_CALLS"
or fail "failed task export deleted a task"

set -gx TASK_MODE import_fail
set -l import_file "$WORKTIME_DIR/tw-personal-export-test.json"
echo '[]' >"$import_file"
_taskwarrior::import_label personal &>/dev/null
and fail "failed task import was masked"
test -f "$import_file"
or fail "failed task import consumed its file"
rm "$import_file"

function record_task_step
    echo $argv[1] >>"$TEST_CALLS"
    test "$TEST_FAIL" != "$argv[1]"
end

function _taskwarrior::export_tag
    record_task_step $argv[1]
end
function taskwarrior::export::bd
    record_task_step bd
end
function taskwarrior::export::maybe
    record_task_step maybe
end
function taskwarrior::export::wins
    record_task_step wins
end
function taskwarrior::export::add
    record_task_step add
end
set -gx TEST_FAIL rocky
: >"$TEST_CALLS"
taskwarrior::export >/dev/null
and fail "failed early task export reported success"
# work/personal + earth + rocky + zen + bd + maybe + wins + add
test (count (cat "$TEST_CALLS")) -eq 8
or fail "failed task export skipped a later export"

function _taskwarrior::import_label
    record_task_step $argv[1]
end
set -gx TEST_FAIL personal
: >"$TEST_CALLS"
taskwarrior::import >/dev/null
and fail "failed first task import label reported success"
test (count (cat "$TEST_CALLS")) -eq 2
or fail "failed task import skipped the hostname label"

function taskwarrior::export
    record_task_step export
end
function taskwarrior::import
    record_task_step import
end
function taskwarrior::cleanup
    record_task_step cleanup
end
function taskwarrior::random_quote
    record_task_step random_quote
end
function taskwarrior::unscheduled
    record_task_step unscheduled
end
function taskwarrior::quicklog_import
    record_task_step quicklog_import
end
function taskwarrior::quicklogger
    record_task_step quicklogger
end
function taskwarrior::gos_queue
    record_task_step gos_queue
end
printf '%s\n' \
    '#!/usr/bin/env sh' \
    'echo task >> "$TEST_CALLS"' \
    'for arg in "$@"; do if [ "$arg" = count ]; then if [ "$TEST_COUNT" = 0 ]; then echo 0; else echo 1; fi; break; fi; done' \
    'exit 0' \
    >"$TEST_ROOT/bin/task"
chmod +x "$TEST_ROOT/bin/task"
function update::tools
    return 0
end

echo 123 >"$SUPERSYNC_STAMP_FILE"
: >"$TEST_CALLS"
set -gx TEST_FAIL import
supersync >/dev/null 2>&1
and fail "failed taskwarrior import reported success"
test (cat "$SUPERSYNC_STAMP_FILE") = 123
or fail "failed taskwarrior import advanced the daily stamp"
test (count (cat "$TEST_CALLS")) -eq 14
or fail "failed taskwarrior import skipped a later invoke step"

set -gx TEST_FAIL none
supersync >/dev/null 2>&1
or fail "successful taskwarrior integration run failed"
test (cat "$SUPERSYNC_STAMP_FILE") -gt 123
or fail "successful taskwarrior integration run did not advance the daily stamp"

echo 123 >"$SUPERSYNC_STAMP_FILE"
: >"$TEST_CALLS"
set -gx TEST_COUNT 0
supersync >/dev/null 2>&1
or fail "no matching tag updates should be successful"
test (count (cat "$TEST_CALLS")) -eq 11
or fail "empty tag filters ran a modify command"

echo 'supersync_helper_failures: ok'
