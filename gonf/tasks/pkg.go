package tasks

import (
	. "github.com/snonux/gonf/api"
)

// Pkg contains tasks that mutate the system package database.
type Pkg struct {
	RequiresRoot
}

func (Pkg) DescFedora() string { return "Install Fedora packages" }

// Fedora installs the workstation package set. It also uninstalls the Rex
// deployment tool: every Rexfile it used to run (this repo's and conf's) has
// been ported to gonf and retired, so an explicit absent resource converges
// hosts that still carry it instead of merely no longer installing it.
func (Pkg) Fedora() {
	NoPackage("Rex")
	Package(List(
		"opendoas",
		"fd-find",
		"nodejs-bash-language-server",
		"fortune-mod",
		"syncthing",
		"ncdu",
		"ack",
		"fish",
		"bat",
		"ctags",
		"fzf",
		"golang",
		"gopls",
		"gpaste",
		"gron",
		"htop",
		"java-latest-openjdk-devel",
		"lynx",
		"make",
		"nodejs22",
		"perl-File-Slurp",
		"procs",
		"rakudo",
		"ripgrep",
		"ruby",
		"strace",
		"task",
		"tig",
		"tmux",
		"dialect",
		"chromium",
		"strawberry",
		"gnumeric",
		"sway-config-fedora",
		"sway",
		"waybar",
		"zathura",
		"flameshot",
	))
}
