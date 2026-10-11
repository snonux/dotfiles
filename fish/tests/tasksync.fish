#!/usr/bin/env fish

# Use the real POSIX sh to read synthetic credentials, and never run task.
set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home space; touch injected; #"
set -gx TEST_ENV "$TEST_ROOT/env"
set -gx TEST_ARGS "$TEST_ROOT/args"
set -gx TEST_TASK_STATUS 0
set -l names GARAGE_ENDPOINT GARAGE_REGION GARAGE_BUCKET \
    GARAGE_ACCESS_KEY_ID GARAGE_SECRET_ACCESS_KEY TASK_SYNC_SECRET
set -l creds "$HOME/.config/garage/taskwarrior-sync.env"
mkdir -p (dirname "$creds") "$TEST_ROOT/bin"
or exit 1

function remove_test_root --on-event fish_exit
    command rm -rf "$TEST_ROOT"
end

function fail
    echo "tasksync: $argv" >&2
    exit 1
end

printf '%s\n' \
    '#!/bin/sh' \
    'printenv GARAGE_ENDPOINT GARAGE_REGION GARAGE_BUCKET GARAGE_ACCESS_KEY_ID GARAGE_SECRET_ACCESS_KEY TASK_SYNC_SECRET AWS_ENDPOINT_URL_S3 > "$TEST_ENV"' \
    'printf "%s\n" "$@" > "$TEST_ARGS"' \
    'exit "$TEST_TASK_STATUS"' >"$TEST_ROOT/bin/task"
chmod +x "$TEST_ROOT/bin/task"
set -gx PATH "$TEST_ROOT/bin" $PATH
source (dirname (status filename))/../conf.d/tasksync.fish
or fail "could not source wrapper"
cd "$TEST_ROOT"
or fail "could not enter test sandbox"

function assert_refused
    command rm -f "$TEST_ENV" "$TEST_ARGS"
    tasksync > /dev/null 2>&1
    test $status -ne 0
    or fail "$argv[1] reported success"
    test ! -e "$TEST_ARGS"
    or fail "$argv[1] invoked task"
end

# Inherited variables must never turn a failed credential source into a sync.
for name in $names
    set -gx $name "inherited $name"
end
assert_refused missing
printf '%s\n' 'false' >"$creds"
assert_refused 'failed source'
printf '%s\n' 'if then' >"$creds"
assert_refused malformed
chmod 000 "$creds"
if test -r "$creds"
    fail "unreadable fixture is readable (run this test without root)"
end
assert_refused unreadable
chmod 600 "$creds"

# A valid file may use shell defaults and existing exported values.
printf '%s\n' \
    ': "${GARAGE_ENDPOINT:=default endpoint}"' \
    ': "${GARAGE_REGION:=default region}"' \
    ': "${GARAGE_BUCKET:=default bucket}"' \
    ': "${GARAGE_ACCESS_KEY_ID:=default access}"' \
    ': "${GARAGE_SECRET_ACCESS_KEY:=default secret}"' \
    ': "${TASK_SYNC_SECRET:=default sync}"' \
    'export GARAGE_ENDPOINT GARAGE_REGION GARAGE_BUCKET GARAGE_ACCESS_KEY_ID GARAGE_SECRET_ACCESS_KEY TASK_SYNC_SECRET' >"$creds"
set -gx AWS_ENDPOINT_URL_S3 'caller endpoint'
tasksync > /dev/null 2>&1
or fail "inherited defaults failed"
set -l actual (cat "$TEST_ENV")
for index in (seq 6)
    test "$actual[$index]" = "inherited $names[$index]"
    or fail "inherited value changed at index $index"
end
test "$actual[7]" = "$actual[1]"
or fail "task endpoint differs from credentials"

for name in $names
    set -e $name
end
tasksync > /dev/null 2>&1
or fail "file defaults failed"
set -l expected 'default endpoint' 'default region' 'default bucket' \
    'default access' 'default secret' 'default sync' 'default endpoint'
set actual (cat "$TEST_ENV")
test (string join '|' -- $actual) = (string join '|' -- $expected)
or fail "default values changed"

# Missing values refuse the call before it reaches the stub.
printf '%s\n' 'export GARAGE_ENDPOINT=endpoint' >"$creds"
assert_refused 'missing values'
# Keep the existing distinction between an unset value and an exported empty
# value; this path fix does not introduce a new credential validation policy.
printf '%s\n' \
    'export GARAGE_ENDPOINT=endpoint GARAGE_REGION=region GARAGE_BUCKET=bucket' \
    'export GARAGE_ACCESS_KEY_ID=access GARAGE_SECRET_ACCESS_KEY=secret TASK_SYNC_SECRET=' >"$creds"
tasksync > /dev/null 2>&1
or fail "exported empty value changed existing behavior"

# Shell metacharacters in the path, secret values and argv stay literal.
printf '%s\n' \
    "export GARAGE_ENDPOINT='https://example.invalid/s3 with space'" \
    "export GARAGE_REGION='region with space'" \
    "export GARAGE_BUCKET='bucket; name'" \
    "export GARAGE_ACCESS_KEY_ID='access * key'" \
    'export GARAGE_SECRET_ACCESS_KEY=\'synthetic $(touch value-injected); secret\'' \
    'export TASK_SYNC_SECRET=\'synthetic `touch value-injected` sync\'' >"$creds"
tasksync 'argument with spaces' '; touch arg-injected' '*' '' > /dev/null 2>&1
or fail "credential path with spaces and metacharacters failed"
set actual (cat "$TEST_ENV")
set expected 'https://example.invalid/s3 with space' 'region with space' \
    'bucket; name' 'access * key' 'synthetic $(touch value-injected); secret' \
    'synthetic `touch value-injected` sync' 'https://example.invalid/s3 with space'
test (string join '|' -- $actual) = (string join '|' -- $expected)
or fail "credential values lost their boundaries"
set -l arguments (cat "$TEST_ARGS" | string collect --allow-empty)
test "$arguments" = (printf '%s\n' sync 'argument with spaces' '; touch arg-injected' '*' '' | string collect --allow-empty)
or fail "task arguments lost their boundaries"
for marker in injected value-injected arg-injected
    test ! -e "$TEST_ROOT/$marker"
    or fail "shell metacharacters executed"
end
test "$AWS_ENDPOINT_URL_S3" = 'caller endpoint'
or fail "endpoint leaked into caller environment"
for name in $names
    set -q $name
    and fail "credential escaped the subprocess"
end
set -gx TEST_TASK_STATUS 17
tasksync > /dev/null 2>&1
test $status -eq 17
or fail "task failure status was lost"

echo 'tasksync: ok'
