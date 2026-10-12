#!/usr/bin/env fish

set -gx TEST_ROOT (mktemp -d)
or exit 1
set -gx HOME "$TEST_ROOT/home"
mkdir -p "$HOME"

function remove_test_root --on-event fish_exit
    cd /
    command rm -r -- "$TEST_ROOT"
end

function fail
    echo "tmpnew: $argv" >&2
    exit 1
end

source (dirname (status filename))/../conf.d/tmputils.fish >/dev/null
or fail "could not source tmputils"

function tmux::attach
    printf '%s\n' "$argv[1]" >"$TEST_ROOT/attached"
end

function fzf
    while read -l candidate
        if test "$candidate" = '[existing] adhoc'
            echo "$candidate"
        end
    end
end

tmpnew >/dev/null
or fail "missing names file prevented selection of an existing directory"
test (pwd) = "$TMPUTILS_DIR/adhoc"
or fail "existing directory was not entered without a names file"
test (cat "$TEST_ROOT/attached") = 'adhoc'
or fail "existing directory was not passed to tmux without a names file"
command rm "$TEST_ROOT/attached"

printf 'first choice\nproject with spaces\nalready-listed\nlast choice\n' >"$HOME/.tmpnewnames"
mkdir -p "$TMPUTILS_DIR/already-listed" "$TMPUTILS_DIR/existing-only"

function fzf
    while read -l candidate
        echo "$candidate" >>"$TEST_ROOT/fzf-input"
        if test "$candidate" = '[new]      project with spaces'
            echo "$candidate"
        end
    end
end

tmpnew >/dev/null
or fail "selection from names file failed"
test (pwd) = "$TMPUTILS_DIR/project with spaces"
or fail "selected directory was not entered"
test -d .git
or fail "selected directory was not initialized as a git repository"
test (cat "$TEST_ROOT/attached") = 'project with spaces'
or fail "selected name was not passed to tmux"
string match -q -e '[new]      first choice' <"$TEST_ROOT/fzf-input"
or fail "configured new name was not labeled new"
string match -q -e '[existing] already-listed' <"$TEST_ROOT/fzf-input"
or fail "configured name with a directory was not labeled existing"
test (string match -e '[existing] already-listed' <"$TEST_ROOT/fzf-input" | count) -eq 1
or fail "name present in both sources was not deduplicated"
string match -q -e '[existing] existing-only' <"$TEST_ROOT/fzf-input"
or fail "existing directory absent from the names file was not offered"

command rm "$TEST_ROOT/attached"
function fzf
    while read -l candidate
        if test "$candidate" = '[existing] existing-only'
            echo "$candidate"
        end
    end
end

tmpnew >/dev/null
or fail "selection of an existing directory failed"
test (pwd) = "$TMPUTILS_DIR/existing-only"
or fail "existing directory was not entered"
test (cat "$TEST_ROOT/attached") = 'existing-only'
or fail "existing directory name was not passed to tmux"

command rm "$TEST_ROOT/attached"
function fzf
    return 130
end

tmpnew >/dev/null 2>/dev/null
set -l cancel_status $status
test $cancel_status -eq 1
or fail "cancelled selection returned status $cancel_status instead of 1"
test ! -e "$TEST_ROOT/attached"
or fail "cancelled selection attached to tmux"

echo 'tmpnew: ok'
