package home

import (
	"os"

	"codeberg.org/snonux/dotfiles/gonf/paths"
	. "github.com/snonux/gonf/api"
)

// HomeTasks holds the home_* tasks: RegisterMethods derives the "home_" prefix
// from the package name.
type HomeTasks struct{}

// config syncs dotfiles/<name>/ into ~/.config/<name>/.
func config(name string) {
	SyncDir(Home(".config/"+name), paths.Dot+"/"+name+"/*")
}

func (HomeTasks) DescHelix() string { return "Install ~/.config/helix" }
func (HomeTasks) Helix() {
	config("helix")
}

func (HomeTasks) DescGhostty() string { return "Install ~/.config/ghostty" }
func (HomeTasks) Ghostty() {
	config("ghostty")
}

func (HomeTasks) DescHexai() string     { return "Install ~/.config/hexai (Linux)" }
func (HomeTasks) WhenHexai() TaskOption { return WhenLinux() }
func (HomeTasks) Hexai() {
	config("hexai")
}

func (HomeTasks) DescTimesamurai() string { return "Install ~/.config/timesamurai" }
func (HomeTasks) Timesamurai() {
	config("timesamurai")
}

func (HomeTasks) DescLazygit() string { return "Install ~/.config/lazygit" }
func (HomeTasks) Lazygit() {
	config("lazygit")
}

func (HomeTasks) DescOpencode() string { return "Install ~/.config/opencode" }
func (HomeTasks) Opencode() {
	config("opencode")
}

func (HomeTasks) DescAgents() string { return "Install agent command/skill symlinks" }
func (HomeTasks) Agents() {
	commands := paths.NotesPrompts + "/commands"
	skills := paths.NotesPrompts + "/skills"
	if _, err := os.Stat(commands); err != nil {
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

func (HomeTasks) DescPrompts() string { return "Legacy alias for home_agents" }
func (HomeTasks) Prompts() {
	_ = Run("home_agents")
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
	config("tmux")
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

func (HomeTasks) DescGitconfig() string     { return "Set global git config (Linux)" }
func (HomeTasks) WhenGitconfig() TaskOption { return WhenLinux() }
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
func (HomeTasks) Calendar() {
	if _, err := os.Stat(paths.DotPrivate); err != nil {
		return
	}
	SyncDir(Home(".calendar"), paths.DotPrivate+"/calendar/*")
}

func (HomeTasks) DescPipewire() string { return "Install pipewire high-res config" }
func (HomeTasks) Pipewire() {
	Dir(Home(".config/pipewire"), WithMode(0o750))
	InstallFile(Home(".config/pipewire/pipewire.conf"), paths.Dot+"/pipewire/pipewire.conf", WithMode(0o600))
}

func (HomeTasks) DescQuickedit() string     { return "Manage ~/QuickEdit symlinks" }
func (HomeTasks) WhenQuickedit() TaskOption { return WhenOS("linux", "freebsd") }
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

func (HomeTasks) DescSystemdUser() string { return "Install and enable systemd user units" }
func (HomeTasks) SystemdUser() {
	units := SyncDir(Home(".config/systemd/user"), paths.Dot+"/systemd-user/*")
	quicklogDrain := InstallFile(Home("scripts/quicklog-drain"), paths.Dot+"/scripts/quicklog-drain", WithMode(0o750))
	reload := DaemonReload(WithUser, DependsOn(units), IfChanged)
	Timer("random-wallpaper", WithUser, DependsOn(reload))
	Timer("home-backup", WithUser, DependsOn(reload))
	Timer("quicklog-drain", WithUser, DependsOn(reload, quicklogDrain))
}

func (HomeTasks) DescTaskwarrior() string     { return "Install ~/.taskrc (Taskwarrior 3.x)" }
func (HomeTasks) WhenTaskwarrior() TaskOption { return WhenLinux() }
func (HomeTasks) Taskwarrior() {
	InstallFile(Home(".taskrc"), paths.Dot+"/taskwarrior/taskrc")
}
