#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
mkdir -p "$HOME" "$TEST_ROOT/bin"
or exit 1

function remove_test_root --on-event fish_exit
    rm -rf "$TEST_ROOT"
end

function fail
    echo "random_delay: $argv" >&2
    exit 1
end

# Exercise the real random builtin but never wait or call the real sleep.
printf '%s\n' '#!/bin/sh' \
    'printf "%s\n" "$@" > "$SLEEP_CALL_LOG"' \
    'exit "$SLEEP_EXIT_STATUS"' >"$TEST_ROOT/bin/sleep"
chmod +x "$TEST_ROOT/bin/sleep"
or fail 'could not create sleep stub'
set -gx PATH "$TEST_ROOT/bin" $PATH
set -gx SLEEP_CALL_LOG "$TEST_ROOT/call"
set -gx SLEEP_EXIT_STATUS 0
set -e RANDOM

source (dirname (status filename))/../conf.d/utils.fish
or fail 'could not source utils'

for bound in 1 2 10 32769 9007199254740992 00010
    for attempt in (seq 1 20)
        random "$bound" >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
        or fail "bound $bound failed"
        test ! -s "$TEST_ROOT/stderr"
        or fail "bound $bound wrote an error"
        set -l delay (cat "$SLEEP_CALL_LOG")
        test (count $delay) -eq 1
        or fail "bound $bound passed the wrong number of sleep arguments"
        string match -qr '^[0-9]+$' -- "$delay"
        or fail "bound $bound passed a noninteger duration"
        test "$delay" -ge 0; and test "$delay" -lt "$bound"
        or fail "duration $delay is outside [0, $bound)"
        printf 'Sleeping %s seconds\n' "$delay" >"$TEST_ROOT/expected"
        diff -u "$TEST_ROOT/expected" "$TEST_ROOT/stdout"
        or fail 'output did not match the sleep duration'
    end
end

set -l newline_bound (printf '1\n' | string collect --no-trim-newlines)
for invalid in '' 0 000 -1 1.5 abc '+1' '1 2' "$newline_bound" 9007199254740993 9223372036854775807 999999999999999999999999999999999
    rm -f "$SLEEP_CALL_LOG"
    random "$invalid" >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
    set -l invalid_status $status
    test "$invalid_status" -eq 2
    or fail "invalid bound '$invalid' returned $invalid_status"
    test ! -e "$SLEEP_CALL_LOG"; and test ! -s "$TEST_ROOT/stdout"
    or fail "invalid bound '$invalid' reached sleep or wrote stdout"
    printf '%s\n' 'Usage: random BOUND (integer from 1 to 9007199254740992)' >"$TEST_ROOT/expected"
    diff -u "$TEST_ROOT/expected" "$TEST_ROOT/stderr"
    or fail "invalid bound '$invalid' did not explain supported bounds"
end

for invalid_case in missing extra
    rm -f "$SLEEP_CALL_LOG"
    if test "$invalid_case" = missing
        random >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
    else
        random 10 20 >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
    end
    set -l invalid_status $status
    test "$invalid_status" -eq 2
    or fail "$invalid_case arguments returned $invalid_status"
    test ! -e "$SLEEP_CALL_LOG"; and test ! -s "$TEST_ROOT/stdout"
    or fail "$invalid_case arguments reached sleep or wrote stdout"
    diff -u "$TEST_ROOT/expected" "$TEST_ROOT/stderr"
    or fail "$invalid_case arguments did not explain supported bounds"
end

set -gx SLEEP_EXIT_STATUS 73
random 1 >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
set -l external_status $status
test "$external_status" -eq 73
or fail "returned $external_status instead of external sleep status 73"
test (cat "$SLEEP_CALL_LOG") = 0
or fail 'bound 1 did not pass zero to sleep on failure'

echo 'random_delay: ok'
