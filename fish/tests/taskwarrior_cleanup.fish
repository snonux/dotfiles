#!/usr/bin/env fish

set -gx QUICKLOG_HEADLESS 1
source (dirname (status filename))/../conf.d/taskwarrior.fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
function remove_test_root --on-event fish_exit
    rm -rf $TEST_ROOT
end

function fail
    echo "taskwarrior_cleanup: $argv" >&2
    exit 1
end

function seed_db
    set -gx TASKDATA "$TEST_ROOT/$argv[1]"
    mkdir -p "$TASKDATA/AgentsHistory"
    sqlite3 "$TASKDATA/taskchampion.sqlite3" "
        CREATE TABLE tasks (uuid TEXT PRIMARY KEY, data TEXT NOT NULL);
        INSERT INTO tasks VALUES (
            'agent-1', '{\"uuid\":\"agent-1\",\"status\":\"completed\",\"end\":1,\"tags\":\"agent\"}'
        );
        INSERT INTO tasks VALUES (
            'plain-1', '{\"uuid\":\"plain-1\",\"status\":\"completed\",\"end\":1}'
        );
        INSERT INTO tasks VALUES (
            'deleted-1', '{\"uuid\":\"deleted-1\",\"status\":\"deleted\",\"end\":1,\"modified\":'
                || CAST(strftime('%s', 'now') AS TEXT) || '}'
        );
    "
    or fail "could not create test database"
    set -gx TASK_CALLS "$TASKDATA/task-calls"
    touch $TASK_CALLS
end

function task
    string join ' ' -- $argv >>$TASK_CALLS
end

# An intact archive permits the completed-task deletion and deleted-task purge.
seed_db success
taskwarrior::cleanup >/dev/null
or fail "cleanup failed with valid archive"
set -l archives (find "$TASKDATA/AgentsHistory" -name 'tw-agent-export-*.json')
test (count $archives) -eq 1
or fail "expected one archive"
jq -e 'length == 1 and .[0].uuid == "agent-1"' $archives[1] >/dev/null
or fail "archive does not contain the agent task"
test (count (cat $TASK_CALLS)) -eq 3
or fail "expected non-agent deletion, archived agent deletion, and purge"
string match -q '*status:completed*delete' (head -n 1 $TASK_CALLS)
or fail "completed deletion was not called"
string match -q '*-agent delete' (head -n 1 $TASK_CALLS)
or fail "non-agent deletion did not exclude agent tasks"
string match -q '*agent-1*+agent delete' (sed -n '2p' $TASK_CALLS)
or fail "agent deletion was not limited to archived UUIDs"
string match -q '*status:completed end.before:today-90days -agent delete' (head -n 1 $TASK_CALLS)
or fail "completed deletion did not require 90 days since completion"
# deleted-1 was modified just now but deleted long ago: deletion age counts.
string match -q '*status:deleted end.before:today-90days purge' (sed -n '3p' $TASK_CALLS)
or fail "purge did not require 90 days since deletion"

# Tasks completed or deleted 89 days ago are kept; at 91 days they go.
function seed_aged
    seed_db $argv[1]
    sqlite3 "$TASKDATA/taskchampion.sqlite3" "
        UPDATE tasks SET data = json_set(data, '\$.end',
            CAST(strftime('%s', 'now', '-$argv[2] days') AS INTEGER));
    "
    or fail "could not age test tasks"
end
seed_aged young 89
taskwarrior::cleanup >/dev/null
or fail "cleanup failed with young tasks"
test (count (cat $TASK_CALLS)) -eq 0
or fail "tasks completed or deleted under 90 days ago were removed"
test (count (find "$TASKDATA/AgentsHistory" -type f)) -eq 0
or fail "young agent task was archived"
seed_aged old 91
taskwarrior::cleanup >/dev/null
or fail "cleanup failed with 91-day-old tasks"
test (count (cat $TASK_CALLS)) -eq 3
or fail "tasks completed or deleted 91 days ago were not removed"

# The SQLite selection uses Taskwarrior's today-90days cutoff (local midnight
# minus 90*86400s), so it never selects tasks the task filter would skip.
function seed_at_cutoff
    seed_db $argv[1]
    sqlite3 "$TASKDATA/taskchampion.sqlite3" "
        UPDATE tasks SET data = json_set(data, '\$.end',
            CAST(strftime('%s', 'now', 'localtime', 'start of day', 'utc') AS INTEGER)
            - 90 * 86400 + $argv[2]);
    "
    or fail "could not place test tasks at the cutoff"
end
# Seeding and cleanup each compute the cutoff; redo a case that spans midnight.
function cleanup_at_cutoff
    while true
        set -l day (date +%F)
        rm -rf "$TEST_ROOT/$argv[1]"
        seed_at_cutoff $argv
        taskwarrior::cleanup >/dev/null
        or fail "cleanup failed with tasks $argv[2]s from the cutoff"
        test (date +%F) = $day; and break
    end
end
cleanup_at_cutoff after_cutoff 1
test (count (cat $TASK_CALLS)) -eq 0
or fail "tasks ended after today-90days were removed"
cleanup_at_cutoff before_cutoff -1
test (count (cat $TASK_CALLS)) -eq 3
or fail "tasks ended before today-90days were not removed"

# A UUID absent from the database must not produce an empty or partial archive.
set -l missing_archive "$TASKDATA/AgentsHistory/missing.json"
_taskwarrior::archive_uuids $missing_archive agent-1 absent-1
and fail "archive accepted a missing UUID"
test -e $missing_archive
and fail "incomplete archive was published"

# Even a successful sqlite3 exit must not publish malformed or short output.
set -g MOCK_SQLITE_OUTPUT '[{'
function sqlite3
    if test "$argv[1]" = :memory:
        command sqlite3 $argv
    else
        printf '%s\n' $MOCK_SQLITE_OUTPUT
    end
end
set -l truncated_archive "$TASKDATA/AgentsHistory/truncated.json"
_taskwarrior::archive_uuids $truncated_archive agent-1 2>/dev/null
and fail "archive accepted malformed output"
test -e $truncated_archive
and fail "malformed archive was published"
set -g MOCK_SQLITE_OUTPUT '[]'
set -l short_archive "$TASKDATA/AgentsHistory/short.json"
_taskwarrior::archive_uuids $short_archive agent-1
and fail "archive accepted valid JSON with too few records"
test -e $short_archive
and fail "short archive was published"
functions -e sqlite3
set -e MOCK_SQLITE_OUTPUT

# A destination created while sqlite3 runs must survive unchanged.
set -gx COLLISION_TARGET "$TASKDATA/AgentsHistory/collision.json"
function sqlite3
    if test "$argv[1]" = :memory:
        command sqlite3 $argv
    else
        echo existing-archive >$COLLISION_TARGET
        command sqlite3 $argv
    end
end
_taskwarrior::archive_uuids $COLLISION_TARGET agent-1 2>/dev/null
and fail "archive overwrote a concurrent destination"
test (cat $COLLISION_TARGET) = existing-archive
or fail "concurrent destination changed"
functions -e sqlite3
set -e COLLISION_TARGET

# A newly eligible agent task appearing after the archive query stays outside
# both deletion commands, while the non-agent task remains eligible.
seed_db mid_run
functions -c task task_original
function task
    if contains -- -agent $argv
        sqlite3 "$TASKDATA/taskchampion.sqlite3" "
            INSERT INTO tasks
            SELECT 'agent-2', replace(data, 'agent-1', 'agent-2')
            FROM tasks WHERE uuid = 'agent-1';
        "
    end
    task_original $argv
end
taskwarrior::cleanup >/dev/null
or fail "cleanup failed when a new agent task appeared"
test (count (cat $TASK_CALLS)) -eq 3
or fail "mid-run cleanup did not call the expected commands"
string match -q '*-agent delete' (head -n 1 $TASK_CALLS)
or fail "mid-run non-agent deletion lacked tag exclusion"
string match -q '*agent-1*+agent delete' (sed -n '2p' $TASK_CALLS)
or fail "mid-run agent deletion lacked archived UUID restriction"
if string match -q '*agent-2*' (cat $TASK_CALLS)
    fail "new agent UUID appeared in deletion commands"
end
functions -e task
functions -c task_original task
functions -e task_original

# A corrupt payload makes sqlite3 fail; cleanup must stop before either task call.
seed_db corrupt
sqlite3 "$TASKDATA/taskchampion.sqlite3" "UPDATE tasks SET data = '{bad' WHERE uuid = 'agent-1';"
taskwarrior::cleanup >/dev/null 2>/dev/null
and fail "cleanup accepted a failed sqlite3 export"
test (count (cat $TASK_CALLS)) -eq 0
or fail "cleanup deleted tasks after sqlite3 failed"
test (count (find "$TASKDATA/AgentsHistory" -type f)) -eq 0
or fail "failed sqlite3 export left an archive"

# An unusable archive destination must stop both destructive task calls.
seed_db blocked_destination
rmdir "$TASKDATA/AgentsHistory"
touch "$TASKDATA/AgentsHistory"
taskwarrior::cleanup >/dev/null 2>/dev/null
and fail "cleanup accepted an unusable archive destination"
test (count (cat $TASK_CALLS)) -eq 0
or fail "cleanup deleted tasks without an archive destination"

# A limited UUID selection must not allow deletion of another old agent task.
seed_db incomplete
sqlite3 "$TASKDATA/taskchampion.sqlite3" "
    INSERT INTO tasks
    SELECT 'agent-2', replace(data, 'agent-1', 'agent-2')
    FROM tasks WHERE uuid = 'agent-1';
"
functions -c _taskwarrior::old_uuids _taskwarrior::old_uuids_original
function _taskwarrior::old_uuids
    echo agent-1
end
taskwarrior::cleanup >/dev/null 2>/dev/null
and fail "cleanup accepted an incomplete UUID selection"
test (count (cat $TASK_CALLS)) -eq 0
or fail "cleanup deleted tasks missing from UUID selection"
functions -e _taskwarrior::old_uuids
functions -c _taskwarrior::old_uuids_original _taskwarrior::old_uuids
functions -e _taskwarrior::old_uuids_original

# The caller must also stop when the selected UUID list cannot be archived.
seed_db missing
functions -c _taskwarrior::old_uuids _taskwarrior::old_uuids_original
function _taskwarrior::old_uuids
    echo absent-1
end
taskwarrior::cleanup >/dev/null 2>/dev/null
and fail "cleanup accepted a missing selected UUID"
test (count (cat $TASK_CALLS)) -eq 0
or fail "cleanup deleted tasks after archive was incomplete"
test (count (find "$TASKDATA/AgentsHistory" -type f)) -eq 0
or fail "incomplete export left an archive"

echo 'taskwarrior_cleanup: ok'
