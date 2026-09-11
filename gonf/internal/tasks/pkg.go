package tasks

import (
	. "github.com/snonux/gonf/api"
)

type Pkg struct{}

func (Pkg) DescFedora() string { return "Install Fedora packages" }

func (Pkg) Fedora() {
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
		"Rex",
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
	))
}
