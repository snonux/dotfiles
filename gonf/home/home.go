package home

import (
	"errors"
	"fmt"
	"os"

	"github.com/snonux/dotfiles/gonf/paths"
	. "github.com/snonux/gonf/api"
)

// HomeTasks contains tasks that manage unprivileged resources under $HOME.
type HomeTasks struct{}

// config syncs dotfiles/<name>/ into ~/.config/<name>/ on the destination.
func config(name string) {
	SyncDir(DestHome(".config/"+name), paths.Dot(name+"/*"))
}

// Helix installs ~/.config/helix.
func (HomeTasks) Helix() {
	config("helix")
}

// Ghostty installs ~/.config/ghostty.
func (HomeTasks) Ghostty() {
	config("ghostty")
}

func (HomeTasks) OptsHexai() TaskOptions { return TaskOptions{WhenLinux()} }

// Hexai installs ~/.config/hexai (Linux).
func (HomeTasks) Hexai() {
	config("hexai")
}

// Timesamurai installs ~/.config/timesamurai.
func (HomeTasks) Timesamurai() {
	config("timesamurai")
}

// Lazygit installs ~/.config/lazygit.
func (HomeTasks) Lazygit() {
	config("lazygit")
}

// Opencode installs ~/.config/opencode.
func (HomeTasks) Opencode() {
	config("opencode")
}

// Agents installs agent command/skill symlinks.
//
// Agents links every agent tool's commands/skills to the controller's
// Notes/Prompts checkout. That checkout is optional (a controller without
// it skips the task), but an unreadable one fails the run.
func (HomeTasks) Agents() {
	if !optionalControllerSource("home_agents", paths.NotesPrompts("commands")) {
		return
	}
	if !optionalControllerSource("home_agents", paths.NotesPrompts("skills")) {
		return
	}
	commands := paths.DestNotesPrompts("commands")
	skills := paths.DestNotesPrompts("skills")

	for _, tool := range List(".cursor", ".claude", ".agents", ".opencode", ".amp") {
		toolDir := DestHome(tool)
		EnsureDir(toolDir, WithMode(0o750))
		Symlink(toolDir+"/commands", commands)
		Symlink(toolDir+"/skills", skills)
	}

	// ~/.pi is often a symlink to an app data dir; EnsureDir rejects that.
	WhenPathExists(DestHome(".pi"), func() {
		Symlink(DestHome(".pi/commands"), commands)
		Symlink(DestHome(".pi/skills"), skills)
	})

	codex := DestHome(".codex")
	EnsureDir(codex, WithMode(0o750))
	Symlink(codex+"/prompts", commands)
}

// Scripts installs ~/scripts.
func (HomeTasks) Scripts() {
	SyncDir(DestHome("scripts"), paths.Dot("scripts/*"), WithFileMode(0o750), WithPrune)
}

// Ssh installs ~/.ssh/config.
func (HomeTasks) Ssh() {
	InstallFile(DestHome(".ssh/config"), paths.Dot("ssh/config"), WithMode(0o600))
}

// Bash installs bash configuration symlinks.
func (HomeTasks) Bash() {
	Symlink(DestHome(".bash_profile"), paths.DestDot("bash/bash_profile"))
	Symlink(DestHome(".bashrc"), paths.DestDot("bash/bashrc"))
}

// Fish installs fish conf.d symlink.
func (HomeTasks) Fish() {
	Symlink(DestHome(".config/fish/conf.d"), paths.DestDot("fish/conf.d"))
}

// FishCompletions installs fish completions.
func (HomeTasks) FishCompletions() {
	SyncDir(DestHome(".config/fish/completions"), paths.Dot("fish/completions/*"))
}

// Gitsyncer installs gitsyncer config symlink.
func (HomeTasks) Gitsyncer() {
	Symlink(DestHome(".config/gitsyncer"), paths.DestDot("gitsyncer"))
}

// Vale installs ~/.vale.ini symlink.
func (HomeTasks) Vale() {
	Symlink(DestHome(".vale.ini"), paths.DestDot("vale.ini"))
}

// Tmux installs ~/.config/tmux.
func (HomeTasks) Tmux() {
	config("tmux")
}

func (HomeTasks) OptsSway() TaskOptions { return TaskOptions{WhenLinux()} }

// Sway installs sway and waybar config (Linux).
func (HomeTasks) Sway() {
	SyncDir(DestHome(".config/sway/config.d"), paths.Dot("sway/config.d/*"))
	SyncDir(DestHome(".config/waybar"), paths.Dot("waybar/*"))
}

// OptsGitconfig skips macOS: git there is configured by hand, so a
// Mac keeps its own global git config. gonf has no negated guard, so this
// lists every other supported OS.
func (HomeTasks) OptsGitconfig() TaskOptions {
	return TaskOptions{WhenOS("linux", "freebsd", "openbsd", "netbsd")}
}

// Gitconfig sets global git config (not on macOS).
func (HomeTasks) Gitconfig() {
	GitGlobal(
		"user.email", "paul@buetow.org",
		"user.name", "Paul Buetow",
		"init.defaultbranch", "main",
		"core.editor", "hx",
		"core.pager", "delta",
		"delta.navigate", "true",
		"delta.side-by-side", "true",
		"delta.features", "side-by-side line-numbers decorations",
		"commit.verbose", "true",
		"interactive.difffilter", "delta --color-only",
		"diff.tool", "difftastic",
		"difftool.prompt", "false",
		"difftool.difftastic.cmd", "difft $LOCAL $REMOTE",
	)
}

// Signature installs ~/.signature.
func (HomeTasks) Signature() {
	InstallFile(DestHome(".signature"), paths.Dot("signature"))
}

// Calendar installs ~/.calendar from private repo.
func (HomeTasks) Calendar() {
	calendar := paths.DotPrivate("calendar")
	if !optionalControllerSource("home_calendar", calendar) {
		return
	}
	SyncDir(DestHome(".calendar"), calendar+"/*")
}

func (HomeTasks) OptsPipewire() TaskOptions { return TaskOptions{WhenLinux()} }

// Pipewire installs pipewire high-res config (Linux).
func (HomeTasks) Pipewire() {
	Dir(DestHome(".config/pipewire"), WithMode(0o750))
	InstallFile(DestHome(".config/pipewire/pipewire.conf"), paths.Dot("pipewire/pipewire.conf"), WithMode(0o600))
}

func (HomeTasks) OptsQuickedit() TaskOptions {
	return TaskOptions{WhenProfile("fedora", "rocky", "freebsd", "darwin")}
}

// Quickedit manages ~/QuickEdit symlinks.
func (HomeTasks) Quickedit() {
	EnsureDir(DestHome("QuickEdit"), WithMode(0o700))
	SymlinkMap(DestHome("QuickEdit"),
		"data", DestHome("data"),
		"Documents", DestHome("Documents"),
		"dotfiles", DestHome("git/dotfiles"),
		"foo.zone-gemtext", DestHome("git/foo.zone-content/gemtext"),
		"Notes", DestHome("Notes"),
		"public-snippets", DestHome("git/conf/snippets"),
		"worktime", DestHome("git/worktime"),
	)
}

func (HomeTasks) OptsSystemdUser() TaskOptions { return TaskOptions{WhenLinux()} }

// SystemdUser installs and enables systemd user units.
func (HomeTasks) SystemdUser() {
	units := SyncDir(DestHome(".config/systemd/user"), paths.Dot("systemd-user/*"))
	quicklogDrain := InstallFile(DestHome("scripts/quicklog-drain"), paths.Dot("scripts/quicklog-drain"), WithMode(0o750))
	// Only the unit files fan into the reload; the quicklog-drain script is
	// an ordering dependency of its timer, so editing it does not reload.
	SystemdUnits(
		WithUserBus(),
		FanIn(units),
		ActivateTimer("home-backup"),
		ActivateTimer("quicklog-drain", DependsOn(quicklogDrain)),
	)
	// The wallpaper timer is simple enough to generate instead of syncing
	// raw unit files; SystemdTimer writes the same unit bytes, reloads, and
	// converges enablement itself.
	SystemdTimer("random-wallpaper",
		WithUser,
		WithCommand("%h/scripts/random-wallpaper.sh"),
		WithOnCalendar("hourly"),
		WithPersistent,
		WithDescription("Set random GNOME wallpaper once per hour"),
		WithServiceDescription("Set random GNOME wallpaper from image directory"),
	)
}

// Taskwarrior installs ~/.taskrc (Taskwarrior 3.x).
func (HomeTasks) Taskwarrior() {
	InstallFile(DestHome(".taskrc"), paths.Dot("taskwarrior/taskrc"))
}

// optionalControllerSource reports whether the optional controller-side
// source directory dir exists, by reading it: a directory that exists but
// cannot be listed (itself or a parent unreadable) would otherwise match no
// files and silently yield an empty sync. Only a missing path
// (os.ErrNotExist) means "skip the task"; any other error, such as a
// permission or I/O error or dir not being a directory, fails the run naming
// the task and path. This is a controller check; destination-side existence
// stays a WhenPathExists guard (see Agents' ~/.pi).
func optionalControllerSource(task, dir string) bool {
	_, err := os.ReadDir(dir)
	switch {
	case err == nil:
		return true
	case errors.Is(err, os.ErrNotExist):
		return false
	default:
		panic(fmt.Errorf("%s: cannot read optional controller source %s: %w", task, dir, err))
	}
}
