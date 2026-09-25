package tasks

import (
	"errors"
	"fmt"
	"os"

	"github.com/snonux/dotfiles/gonf/paths"
	. "github.com/snonux/gonf/api"
)

// HomeTasks contains tasks that manage unprivileged resources under $HOME.
type HomeTasks struct{}

func (HomeTasks) DescHelix() string { return "Install ~/.config/helix" }
func (HomeTasks) Helix() {
	SyncDir(DestHome(".config/helix"), paths.Dot+"/helix/*")
}

func (HomeTasks) DescGhostty() string { return "Install ~/.config/ghostty" }
func (HomeTasks) Ghostty() {
	SyncDir(DestHome(".config/ghostty"), paths.Dot+"/ghostty/*")
}

func (HomeTasks) DescHexai() string      { return "Install ~/.config/hexai (Linux)" }
func (HomeTasks) OptsHexai() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) Hexai() {
	SyncDir(DestHome(".config/hexai"), paths.Dot+"/hexai/*")
}

func (HomeTasks) DescTimesamurai() string { return "Install ~/.config/timesamurai" }
func (HomeTasks) Timesamurai() {
	SyncDir(DestHome(".config/timesamurai"), paths.Dot+"/timesamurai/*")
}

func (HomeTasks) DescLazygit() string { return "Install ~/.config/lazygit" }
func (HomeTasks) Lazygit() {
	SyncDir(DestHome(".config/lazygit"), paths.Dot+"/lazygit/*")
}

func (HomeTasks) DescOpencode() string { return "Install ~/.config/opencode" }
func (HomeTasks) Opencode() {
	SyncDir(DestHome(".config/opencode"), paths.Dot+"/opencode/*")
}

func (HomeTasks) DescAgents() string { return "Install agent command/skill symlinks" }

// Agents links every agent tool's commands/skills to the controller's
// Notes/Prompts checkout. That checkout is optional (a controller without
// it skips the task), but an unreadable one fails the run.
func (HomeTasks) Agents() {
	if !optionalControllerSource("home_agents", paths.NotesPrompts+"/commands") {
		return
	}
	if !optionalControllerSource("home_agents", paths.NotesPrompts+"/skills") {
		return
	}
	commands := paths.DestNotesPrompts + "/commands"
	skills := paths.DestNotesPrompts + "/skills"

	for _, tool := range List(".cursor", ".claude", ".agents", ".opencode", ".amp") {
		toolDir := DestHome(tool)
		EnsureDir(toolDir, WithMode(0o750))
		Link(toolDir+"/commands", WithSymlink(commands))
		Link(toolDir+"/skills", WithSymlink(skills))
	}

	// ~/.pi is often a symlink to an app data dir; EnsureDir rejects that.
	WhenPathExists(DestHome(".pi"), func() {
		Link(DestHome(".pi/commands"), WithSymlink(commands))
		Link(DestHome(".pi/skills"), WithSymlink(skills))
	})

	codex := DestHome(".codex")
	EnsureDir(codex, WithMode(0o750))
	Link(codex+"/prompts", WithSymlink(commands))
}

func (HomeTasks) DescScripts() string { return "Install ~/scripts" }
func (HomeTasks) Scripts() {
	SyncDir(DestHome("scripts"), paths.Dot+"/scripts/*", WithFileMode(0o750), WithPrune)
}

func (HomeTasks) DescSsh() string { return "Install ~/.ssh/config" }
func (HomeTasks) Ssh() {
	InstallFile(DestHome(".ssh/config"), paths.Dot+"/ssh/config", WithMode(0o600))
}

func (HomeTasks) DescBash() string { return "Install bash configuration symlinks" }
func (HomeTasks) Bash() {
	Link(DestHome(".bash_profile"), WithSymlink(paths.DestDot+"/bash/bash_profile"))
	Link(DestHome(".bashrc"), WithSymlink(paths.DestDot+"/bash/bashrc"))
}

func (HomeTasks) DescFish() string { return "Install fish conf.d symlink" }
func (HomeTasks) Fish() {
	Link(DestHome(".config/fish/conf.d"), WithSymlink(paths.DestDot+"/fish/conf.d"))
}

func (HomeTasks) DescFishCompletions() string { return "Install fish completions" }
func (HomeTasks) FishCompletions() {
	SyncDir(DestHome(".config/fish/completions"), paths.Dot+"/fish/completions/*")
}

func (HomeTasks) DescGitsyncer() string { return "Install gitsyncer config symlink" }
func (HomeTasks) Gitsyncer() {
	Link(DestHome(".config/gitsyncer"), WithSymlink(paths.DestDot+"/gitsyncer"))
}

func (HomeTasks) DescVale() string { return "Install ~/.vale.ini symlink" }
func (HomeTasks) Vale() {
	Link(DestHome(".vale.ini"), WithSymlink(paths.DestDot+"/vale.ini"))
}

func (HomeTasks) DescTmux() string { return "Install ~/.config/tmux" }
func (HomeTasks) Tmux() {
	SyncDir(DestHome(".config/tmux"), paths.Dot+"/tmux/*")
}

func (HomeTasks) DescSway() string      { return "Install sway and waybar config (Linux)" }
func (HomeTasks) OptsSway() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) Sway() {
	SyncDir(DestHome(".config/sway/config.d"), paths.Dot+"/sway/config.d/*")
	SyncDir(DestHome(".config/waybar"), paths.Dot+"/waybar/*")
}

func (HomeTasks) DescGitconfig() string { return "Set global git config (not on macOS)" }

// OptsGitconfig skips macOS: git there is configured by hand, so a
// Mac keeps its own global git config. gonf has no negated guard, so this
// lists every other supported OS.
func (HomeTasks) OptsGitconfig() TaskOptions {
	return TaskOptions{WhenOS("linux", "freebsd", "openbsd", "netbsd")}
}
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
	InstallFile(DestHome(".signature"), paths.Dot+"/signature")
}

func (HomeTasks) DescCalendar() string { return "Install ~/.calendar from private repo" }

// Calendar syncs ~/.calendar from the calendar directory of the optional
// conf_private checkout on the controller; without it the task is skipped.
func (HomeTasks) Calendar() {
	calendar := paths.DotPrivate + "/calendar"
	if !optionalControllerSource("home_calendar", calendar) {
		return
	}
	SyncDir(DestHome(".calendar"), calendar+"/*")
}

func (HomeTasks) DescPipewire() string      { return "Install pipewire high-res config (Linux)" }
func (HomeTasks) OptsPipewire() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) Pipewire() {
	Dir(DestHome(".config/pipewire"), WithMode(0o750))
	InstallFile(DestHome(".config/pipewire/pipewire.conf"), paths.Dot+"/pipewire/pipewire.conf", WithMode(0o600))
}

func (HomeTasks) DescQuickedit() string { return "Manage ~/QuickEdit symlinks" }
func (HomeTasks) OptsQuickedit() TaskOptions {
	return TaskOptions{WhenProfile("fedora", "rocky", "freebsd", "darwin")}
}
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

func (HomeTasks) DescSystemdUser() string      { return "Install and enable systemd user units" }
func (HomeTasks) OptsSystemdUser() TaskOptions { return TaskOptions{WhenLinux()} }
func (HomeTasks) SystemdUser() {
	units := SyncDir(DestHome(".config/systemd/user"), paths.Dot+"/systemd-user/*")
	quicklogDrain := InstallFile(DestHome("scripts/quicklog-drain"), paths.Dot+"/scripts/quicklog-drain", WithMode(0o750))
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

func (HomeTasks) DescTaskwarrior() string { return "Install ~/.taskrc (Taskwarrior 3.x)" }
func (HomeTasks) Taskwarrior() {
	InstallFile(DestHome(".taskrc"), paths.Dot+"/taskwarrior/taskrc")
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
