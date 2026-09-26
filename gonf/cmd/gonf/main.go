package main

import (
	"os"

	"github.com/snonux/dotfiles/gonf/home"
	"github.com/snonux/dotfiles/gonf/pkg"
	"github.com/snonux/dotfiles/gonf/system"
	. "github.com/snonux/gonf/api"
	"github.com/snonux/gonf/cli"
)

func main() {
	RegisterMethods(home.HomeTasks{}) // home_*: prefix derived from package home
	// home_prompts is the legacy public name of home_agents. As an Alias it
	// records home_agents' ops directly and the "home" aggregate records them
	// once, instead of a second time through a Run-only wrapper task.
	Alias("home_prompts", "Legacy alias for home_agents", "home_agents")
	// home_tmux_rocky used to append the rocky overrides to tmux.conf after
	// home_tmux synced it, so the two tasks rewrote the same file on every
	// apply. tmux.conf now sources tmux.rocky.conf itself when the hostname
	// contains "rocky", so the old name only needs to run home_tmux. As an
	// Alias it is active wherever home_tmux is (earth included, which a
	// controller-side hostname guard used to hide from -list and "home").
	Alias("home_tmux_rocky", "Legacy alias for home_tmux (rocky overrides load from tmux.conf)", "home_tmux")
	RegisterMethods(pkg.Pkg{}, WithGroupWhen(WhenProfile("fedora"))) // pkg_*
	// System is earth-only (its fleet /etc/hosts block and WireGuard perms
	// describe that laptop), so it is guarded by hostname, not by profile.
	RegisterMethods(system.System{}, WithGroupWhen(WhenHostnameContains("earth"))) // system_*
	Aggregate("home", "Install all home_* configuration", "^home_")
	os.Exit(cli.CLI())
}
