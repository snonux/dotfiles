#!/bin/sh
#
# Run the dotfiles Gonf recipes: ./gonf.sh -list, ./gonf.sh home, ...
#
# Works from any working directory: it changes into this checkout's gonf
# module and runs it there, so relative path arguments such as "plan -o out"
# are relative to that gonf directory, as before. Arguments are passed
# through verbatim.
#
# Source root: the recipes default to ~/git/dotfiles (Home, the logical
# $HOME path). Only when this wrapper lives in a different checkout (a
# second worktree) does it export GONF_DOTFILES_ROOT, as the logical path it
# was invoked by; an existing GONF_DOTFILES_ROOT wins. Symlinks are never
# resolved into physical paths (FreeBSD /home -> /usr/home, Fedora Atomic
# /home -> /var/home), since link targets in the plans would change. The
# checkout is the directory of the path the wrapper was invoked by: calling
# it through a symlink to gonf.sh uses the symlink's directory.
set -eu

repo_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -L)
if [ -z "${GONF_DOTFILES_ROOT:-}" ] && ! [ "$repo_dir" -ef "${HOME:-}/git/dotfiles" ]; then
	GONF_DOTFILES_ROOT=$repo_dir
	export GONF_DOTFILES_ROOT
fi
cd "$repo_dir/gonf"
exec go run ./cmd/gonf "$@"
