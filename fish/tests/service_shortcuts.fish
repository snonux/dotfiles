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
    echo "service_shortcuts: $argv" >&2
    exit 1
end

# An external sudo stub records arguments but never invokes service or sudo.
printf '%s\n' '#!/bin/sh' \
    'printf "%s\n" "$@" > "$SERVICE_CALL_LOG"' \
    'exit "$SERVICE_EXIT_STATUS"' >"$TEST_ROOT/bin/sudo"
chmod +x "$TEST_ROOT/bin/sudo"
or fail 'could not create sudo stub'
set -gx PATH "$TEST_ROOT/bin" $PATH
set -gx SERVICE_CALL_LOG "$TEST_ROOT/call"
set -gx SERVICE_EXIT_STATUS 0

source (dirname (status filename))/../conf.d/utils.fish
or fail 'could not source utils'

for shortcut in start stop restart statuss
    set -l action $shortcut
    if test "$shortcut" = statuss
        set action status
    end

    $shortcut nginx
    or fail "$shortcut rejected a service without trailing arguments"
    printf '%s\n' service nginx "$action" >"$TEST_ROOT/expected"
    diff -u "$TEST_ROOT/expected" "$SERVICE_CALL_LOG"
    or fail "$shortcut duplicated or changed the service operand"

    # Spaces and an empty trailing argument must keep their argument boundaries.
    $shortcut 'service with spaces' --verbose 'argument with spaces' '' --flag
    or fail "$shortcut failed with trailing arguments"
    printf '%s\n' service 'service with spaces' "$action" --verbose \
        'argument with spaces' '' --flag >"$TEST_ROOT/expected"
    diff -u "$TEST_ROOT/expected" "$SERVICE_CALL_LOG"
    or fail "$shortcut changed trailing arguments"

    set -gx SERVICE_EXIT_STATUS 73
    $shortcut nginx --verbose
    set -l external_status $status
    test "$external_status" -eq 73
    or fail "$shortcut returned $external_status instead of external status 73"
    printf '%s\n' service nginx "$action" --verbose >"$TEST_ROOT/expected"
    diff -u "$TEST_ROOT/expected" "$SERVICE_CALL_LOG"
    or fail "$shortcut changed arguments on external failure"
    set -gx SERVICE_EXIT_STATUS 0

    for invalid_case in missing empty
        rm -f "$SERVICE_CALL_LOG"
        if test "$invalid_case" = missing
            $shortcut >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
        else
            $shortcut '' --verbose >"$TEST_ROOT/stdout" 2>"$TEST_ROOT/stderr"
        end
        set -l invalid_status $status
        test "$invalid_status" -eq 2
        or fail "$shortcut returned $invalid_status for $invalid_case service"
        test ! -e "$SERVICE_CALL_LOG"
        or fail "$shortcut invoked sudo for $invalid_case service"
        test ! -s "$TEST_ROOT/stdout"
        or fail "$shortcut wrote validation output to stdout"
        printf 'Usage: %s SERVICE [ARG ...]\n' "$shortcut" >"$TEST_ROOT/expected"
        diff -u "$TEST_ROOT/expected" "$TEST_ROOT/stderr"
        or fail "$shortcut did not explain the missing service"
    end
end

echo 'service_shortcuts: ok'
