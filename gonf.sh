#!/bin/sh
#
# Run the dotfiles Gonf recipes: ./gonf.sh -list, ./gonf.sh home, ...
#
# Works from any working directory: it changes into this checkout's gonf
# module and runs it there, so relative path arguments such as "plan -o out"
# are relative to that gonf directory, as before. GONF_DOTFILES_ROOT is set
# to this checkout (an existing value wins), so recipes install the files of
# the checkout that runs them rather than always ~/git/dotfiles. Arguments
# are passed through verbatim.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
GONF_DOTFILES_ROOT=${GONF_DOTFILES_ROOT:-$repo_dir}
export GONF_DOTFILES_ROOT
cd "$repo_dir/gonf"
exec go run ./cmd/gonf "$@"
