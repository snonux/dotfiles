#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -l test_home "$TEST_ROOT/home"
set -l test_config "$TEST_ROOT/config"
mkdir -p "$test_home" "$test_config/fish/conf.d"
or exit 1

function remove_test_root --on-event fish_exit
    command rm -r -- "$TEST_ROOT"
end

function fail
    echo "config_paths: $argv" >&2
    exit 1
end

# Seed old universal data with both configured and unrelated duplicate paths.
env HOME="$test_home" XDG_CONFIG_HOME="$test_config" fish -c \
    'set -U fish_user_paths "$HOME/extra-a" "$HOME/bin" "$HOME/extra-b" "$HOME/extra-a" "$HOME/flutter/bin"'
or fail "could not seed universal paths"

ln -s (realpath (dirname (status filename))/../conf.d/config.fish) "$test_config/fish/conf.d/config.fish"
or fail "could not install test config"

printf '%s\n' \
    "$test_home/bin" "$test_home/scripts" "$test_home/go/bin" \
    "$test_home/.cargo/bin" "$test_home/.local/bin" "$test_home/flutter/bin" \
    "$test_home/extra-a" "$test_home/extra-b" >"$TEST_ROOT/expected"

for startup in 1 2
    env HOME="$test_home" XDG_CONFIG_HOME="$test_config" fish -c \
        'printf "%s\n" $fish_user_paths' >"$TEST_ROOT/actual-$startup"
    or fail "startup $startup failed"
    diff -u "$TEST_ROOT/expected" "$TEST_ROOT/actual-$startup"
    or fail "startup $startup changed path order or introduced duplicates"
end

echo 'config_paths: ok'
