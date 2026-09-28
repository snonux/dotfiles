#!/usr/bin/env fish

source (dirname (status filename))/../conf.d/taskwarrior.fish

set -g TEST_ROOT (mktemp -d)
or exit 1
function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "taskwarrior_gos_queue: $argv" >&2
    exit 1
end

set -gx GOS_DIR "$TEST_ROOT/gos"
mkdir "$GOS_DIR"
set -g MOCK_UUID share-1
set -g MOCK_DESC 'Progress 100% complete; %s and %d are literal'
set -g MOCK_JSON (jq -nc --arg description "$MOCK_DESC" \
    '[{description: $description, tags: ["share", "li", "soon", "launch", "personal"]}]')
set -g EXPECTED_MESSAGE "share:li,soon $MOCK_DESC"\n\n"#launch"
set -g EXPECTED_FILE "$GOS_DIR/"(builtin printf '%s' "$EXPECTED_MESSAGE" | md5sum | awk '{print $1}')".txt"
set -g DELETE_COUNT 0

function task
    if test "$argv[1]" = +share
        echo "$MOCK_UUID"
    else if test "$argv[1]" = "$MOCK_UUID"; and test "$argv[2]" = export
        echo "$MOCK_JSON"
    else if test "$argv[1]" = "$MOCK_UUID"; and test "$argv[2]" = delete
        if builtin printf '%s\n' "$EXPECTED_MESSAGE" | cmp -s - "$EXPECTED_FILE"
            set -g DELETE_COUNT (math $DELETE_COUNT + 1)
        else
            fail "task was deleted before its complete queue file was present"
        end
    else
        fail "unexpected task call: $argv"
    end
end

# A percent sign and format-like text must be stored literally. Hashtags keep
# their intended blank-line separator, and deletion sees the complete file.
taskwarrior::gos_queue >/dev/null
or fail "queue failed for a description containing percent signs"
test "$DELETE_COUNT" -eq 1
or fail "complete queue write did not delete the task"
builtin printf '%s\n' "$EXPECTED_MESSAGE" | cmp -s - "$EXPECTED_FILE"
or fail "queue file does not contain the exact share text"

# Even if a write reports success after emitting only part of the message,
# the task must stay pending.
rm "$EXPECTED_FILE"
set -g PRINT_CALLS 0
function printf
    if test "$argv[1]" = '%s\n'
        set -g PRINT_CALLS (math $PRINT_CALLS + 1)
        if test "$PRINT_CALLS" -eq 1
            builtin printf '%s\n' short
            return 0
        end
    end
    builtin printf $argv
end
taskwarrior::gos_queue >/dev/null 2>/dev/null
and fail "short queue write reported success"
functions -e printf
test "$DELETE_COUNT" -eq 1
or fail "task was deleted after a short write"
test (cat "$EXPECTED_FILE") = short
or fail "short-write setup did not create a partial file"

# A writer that reports failure must also leave the task pending.
rm "$EXPECTED_FILE"
function printf
    if test "$argv[1]" = '%s\n'
        builtin printf '%s\n' short
        return 1
    end
    builtin printf $argv
end
taskwarrior::gos_queue >/dev/null 2>/dev/null
and fail "failed queue write reported success"
functions -e printf
test "$DELETE_COUNT" -eq 1
or fail "task was deleted after printf failed"

echo 'taskwarrior_gos_queue: ok'
