package tasks

import (
	"os"
	"strings"

	"codeberg.org/snonux/dotfiles/gonf/internal/paths"
	. "github.com/snonux/gonf/api"
	. "github.com/snonux/gonf/api/options"
)

type HomeTasks struct{}

func (HomeTasks) DescHelix() string { return "Install ~/.config/helix" }
func (HomeTasks) Helix() {
	SyncDir(Home(".config/helix"), paths.Dot+"/helix/*")
}

func (HomeTasks) DescGhostty() string { return "Install ~/.config/ghostty" }
func (HomeTasks) Ghostty() {
	SyncDir(Home(".config/ghostty"), paths.Dot+"/ghostty/*")
}

func (HomeTasks) DescHexai() string { return "Install ~/.config/hexai (Linux)" }
func (HomeTasks) WhenHexai(f Facts) bool { return f.GOOS == "linux" }
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
func (HomeTasks) Agents() {
	commands := paths.NotesPrompts + "/commands"
	skills := paths.NotesPrompts + "/skills"
	if _, err := os.Stat(commands); err != nil {
		return
	}

	for _, tool := range Elems(".cursor", ".claude", ".agents", ".opencode", ".pi", ".amp") {
		toolDir := Home(tool)
		EnsureDir(toolDir, WithMode(0o750))
		Link(toolDir+"/commands", WithSymlink(commands))
		Link(toolDir+"/skills", WithSymlink(skills))
	}

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

func (HomeTasks) DescBash() string { return "Install bash configuration" }
func (HomeTasks) Bash() {
	InstallFile(Home(".bash_profile"), paths.Dot+"/bash/bash_profile")
	InstallFile(Home(".bashrc"), paths.Dot+"/bash/bashrc")
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

func (HomeTasks) DescVale() string { return "Install ~/.vale.ini" }
func (HomeTasks) Vale() {
	InstallFile(Home(".vale.ini"), paths.Dot+"/vale.ini")
}

func (HomeTasks) DescTmux() string { return "Install ~/.config/tmux" }
func (HomeTasks) Tmux() {
	SyncDir(Home(".config/tmux"), paths.Dot+"/tmux/*")
}

func (HomeTasks) DescTmuxRocky() string { return "Append rocky tmux overrides when on rocky" }
func (HomeTasks) WhenTmuxRocky(f Facts) bool {
	return And(
		func(f Facts) bool { return f.GOOS == "linux" },
		func(f Facts) bool {
			return strings.Contains(strings.ToLower(f.Hostname), "rocky")
		},
	)(f)
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

func (HomeTasks) DescGitconfig() string { return "Set global git config (Linux)" }
func (HomeTasks) WhenGitconfig(f Facts) bool { return f.GOOS == "linux" }
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

func (HomeTasks) DescQuickedit() string { return "Manage ~/QuickEdit symlinks" }
func (HomeTasks) WhenQuickedit(f Facts) bool {
	return f.GOOS == "linux" || f.GOOS == "freebsd"
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

func (HomeTasks) DescSystemdUser() string { return "Install and enable systemd user units" }
func (HomeTasks) SystemdUser() {
	units := SyncDir(Home(".config/systemd/user"), paths.Dot+"/systemd-user/*")

	Command("systemctl", Elems("--user", "daemon-reload"),
		DependsOn(units),
		WithName("systemctl.daemon-reload"),
	)
	Command("systemctl", Elems("--user", "enable", "random-wallpaper.timer"),
		Unless("systemctl", Elems("--user", "is-enabled", "random-wallpaper.timer")),
		DependsOn(units),
		WithName("systemctl.enable.random-wallpaper"),
	)
	Command("systemctl", Elems("--user", "enable", "home-backup.timer"),
		Unless("systemctl", Elems("--user", "is-enabled", "home-backup.timer")),
		DependsOn(units),
		WithName("systemctl.enable.home-backup"),
	)
}

func (HomeTasks) DescTaskwarrior() string { return "Install ~/.taskrc (Taskwarrior 3.x)" }
func (HomeTasks) WhenTaskwarrior(f Facts) bool { return f.GOOS == "linux" }
func (HomeTasks) Taskwarrior() {
	InstallFile(Home(".taskrc"), paths.Dot+"/taskwarrior/taskrc")
}
