package main

import (
	"github.com/snonux/dotfiles/gonf/home"
	. "github.com/snonux/gonf/api"
	"github.com/snonux/gonf/cli"
)

func main() {
	registerTasks()
	cli.Main()
}

func registerTasks() {
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
	// The home aggregate contains only unprivileged user configuration.
	AggregateTasks("home", "Install unprivileged home configuration",
		"home_aerc",
		"home_agents",
		"home_bash",
		"home_calendar",
		"home_fish",
		"home_fish_completions",
		"home_ghostty",
		"home_gitconfig",
		"home_gitsyncer",
		"home_helix",
		"home_hexai",
		"home_lazygit",
		"home_notes",
		"home_opencode",
		"home_pi",
		"home_pipewire",
		"home_quickedit",
		"home_scripts",
		"home_signature",
		"home_ssh",
		"home_sway",
		"home_systemd_user",
		"home_taskwarrior",
		"home_timesamurai",
		"home_tmux",
		"home_vale",
	)
}
