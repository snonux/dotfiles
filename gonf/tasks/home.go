package tasks

import (
	"errors"
	"fmt"
	"os"

	"codeberg.org/snonux/dotfiles/gonf/paths"
	. "github.com/snonux/gonf/api"
	. "github.com/snonux/gonf/api/options"
)

// HomeTasks contains tasks that manage unprivileged resources under $HOME.
type HomeTasks struct{}

func (HomeTasks) DescHelix() string { return "Install ~/.config/helix" }
func (HomeTasks) Helix() {
	SyncDir(Home(".config/helix"), paths.Dot+"/helix/*")
}

func (HomeTasks) DescGhostty() string { return "Install ~/.config/ghostty" }
func (HomeTasks) Ghostty() {
	SyncDir(Home(".config/ghostty"), paths.Dot+"/ghostty/*")
}

func (HomeTasks) DescHexai() string      { return "Install ~/.config/hexai (Linux)" }
func (HomeTasks) OptsHexai() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) Hexai() {
	SyncDir(Home(".config/hexai"), paths.Dot+"/hexai/*")
}

func (HomeTasks) DescTimesamurai() string { return "Install ~/.config/timesamurai" }
func (HomeTasks) Timesamurai() {
	SyncDir(Home(".config/timesamurai"), paths.Dot+"/timesamurai/*")
}

func (HomeTasks) DescLazygit() string { return "Install ~/.config/lazygit" }
func (HomeTasks) Lazygit() {
	SyncDir(Home(".config/lazygit"), paths.Dot+"/lazygit/*")
}

func (HomeTasks) DescOpencode() string { return "Install ~/.config/opencode" }
func (HomeTasks) Opencode() {
	SyncDir(Home(".config/opencode"), paths.Dot+"/opencode/*")
}

func (HomeTasks) DescAgents() string { return "Install agent command/skill symlinks" }

// Agents links every agent tool's commands/skills to the controller's
// Notes/Prompts checkout. That checkout is optional (a controller without
// it skips the task), but an unreadable one fails the run.
func (HomeTasks) Agents() {
	commands := paths.NotesPrompts + "/commands"
	skills := paths.NotesPrompts + "/skills"
	if !optionalControllerSource("home_agents", commands) {
		return
	}

	for _, tool := range List(".cursor", ".claude", ".agents", ".opencode", ".amp") {
		toolDir := Home(tool)
		EnsureDir(toolDir, WithMode(0o750))
		Link(toolDir+"/commands", WithSymlink(commands))
		Link(toolDir+"/skills", WithSymlink(skills))
	}

	// ~/.pi is often a symlink to an app data dir; EnsureDir rejects that.
	WhenPathExists(Home(".pi"), func() {
		Link(Home(".pi/commands"), WithSymlink(commands))
		Link(Home(".pi/skills"), WithSymlink(skills))
	})

	codex := Home(".codex")
	EnsureDir(codex, WithMode(0o750))
	Link(codex+"/prompts", WithSymlink(commands))
}

func (HomeTasks) DescScripts() string { return "Install ~/scripts" }
func (HomeTasks) Scripts() {
	SyncDir(Home("scripts"), paths.Dot+"/scripts/*", WithFileMode(0o750), WithPrune)
}

func (HomeTasks) DescSsh() string { return "Install ~/.ssh/config" }
func (HomeTasks) Ssh() {
	InstallFile(Home(".ssh/config"), paths.Dot+"/ssh/config", WithMode(0o600))
}

func (HomeTasks) DescBash() string { return "Install bash configuration symlinks" }
func (HomeTasks) Bash() {
	Link(Home(".bash_profile"), WithSymlink(paths.Dot+"/bash/bash_profile"))
	Link(Home(".bashrc"), WithSymlink(paths.Dot+"/bash/bashrc"))
}

func (HomeTasks) DescFish() string { return "Install fish conf.d symlink" }
func (HomeTasks) Fish() {
	Link(Home(".config/fish/conf.d"), WithSymlink(paths.Dot+"/fish/conf.d"))
}

func (HomeTasks) DescFishCompletions() string { return "Install fish completions" }
func (HomeTasks) FishCompletions() {
	SyncDir(Home(".config/fish/completions"), paths.Dot+"/fish/completions/*")
}

func (HomeTasks) DescGitsyncer() string { return "Install gitsyncer config symlink" }
func (HomeTasks) Gitsyncer() {
	Link(Home(".config/gitsyncer"), WithSymlink(paths.Dot+"/gitsyncer"))
}

func (HomeTasks) DescVale() string { return "Install ~/.vale.ini symlink" }
func (HomeTasks) Vale() {
	Link(Home(".vale.ini"), WithSymlink(paths.Dot+"/vale.ini"))
}

func (HomeTasks) DescTmux() string { return "Install ~/.config/tmux" }
func (HomeTasks) Tmux() {
	SyncDir(Home(".config/tmux"), paths.Dot+"/tmux/*")
}

func (HomeTasks) DescTmuxRocky() string { return "Append rocky tmux overrides when on rocky" }
func (HomeTasks) OptsTmuxRocky() TaskOptions {
	return TaskOptions{WhenLinux(), WhenHostnameContains("rocky")}
}
func (HomeTasks) TmuxRocky() {
	line := "source-file ~/.config/tmux/tmux.rocky.conf"
	File(Home(".config/tmux/tmux.local.conf"), WithoutLine(line))
	File(Home(".config/tmux/tmux.conf"), WithLine(line))
}

func (HomeTasks) DescSway() string { return "Install sway and waybar config" }
func (HomeTasks) Sway() {
	SyncDir(Home(".config/sway/config.d"), paths.Dot+"/sway/config.d/*")
	SyncDir(Home(".config/waybar"), paths.Dot+"/waybar/*")
}

func (HomeTasks) DescGitconfig() string      { return "Set global git config (Linux)" }
func (HomeTasks) OptsGitconfig() TaskOptions { return TaskOptions{WhenLinux()} }
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

func (HomeTasks) DescSignature() string { return "Install ~/.signature" }
func (HomeTasks) Signature() {
	InstallFile(Home(".signature"), paths.Dot+"/signature")
}

func (HomeTasks) DescCalendar() string { return "Install ~/.calendar from private repo" }

// Calendar syncs ~/.calendar from the calendar directory of the optional
// conf_private checkout on the controller; without it the task is skipped.
func (HomeTasks) Calendar() {
	calendar := paths.DotPrivate + "/calendar"
	if !optionalControllerSource("home_calendar", calendar) {
		return
	}
	SyncDir(Home(".calendar"), calendar+"/*")
}

func (HomeTasks) DescPipewire() string { return "Install pipewire high-res config" }
func (HomeTasks) Pipewire() {
	Dir(Home(".config/pipewire"), WithMode(0o750))
	InstallFile(Home(".config/pipewire/pipewire.conf"), paths.Dot+"/pipewire/pipewire.conf", WithMode(0o600))
}

func (HomeTasks) DescQuickedit() string { return "Manage ~/QuickEdit symlinks" }
func (HomeTasks) OptsQuickedit() TaskOptions {
	return TaskOptions{WhenProfile("fedora", "rocky", "freebsd")}
}
func (HomeTasks) Quickedit() {
	EnsureDir(Home("QuickEdit"), WithMode(0o700))
	SymlinkMap(Home("QuickEdit"),
		"data", Home("data"),
		"Documents", Home("Documents"),
		"dotfiles", Home("git/dotfiles"),
		"foo.zone-gemtext", Home("git/foo.zone-content/gemtext"),
		"Notes", Home("Notes"),
		"public-snippets", Home("git/conf/snippets"),
		"worktime", Home("git/worktime"),
	)
}

func (HomeTasks) DescSystemdUser() string      { return "Install and enable systemd user units" }
func (HomeTasks) OptsSystemdUser() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) SystemdUser() {
	units := SyncDir(Home(".config/systemd/user"), paths.Dot+"/systemd-user/*")
	quicklogDrain := InstallFile(Home("scripts/quicklog-drain"), paths.Dot+"/scripts/quicklog-drain", WithMode(0o750))
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

func (HomeTasks) DescTaskwarrior() string      { return "Install ~/.taskrc (Taskwarrior 3.x)" }
func (HomeTasks) OptsTaskwarrior() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) Taskwarrior() {
	InstallFile(Home(".taskrc"), paths.Dot+"/taskwarrior/taskrc")
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
