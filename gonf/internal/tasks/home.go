package tasks

import (
	"os"
	"strings"

	"codeberg.org/snonux/dotfiles/gonf/internal/paths"
	"github.com/snonux/gonf/api"
	. "github.com/snonux/gonf/api/options"
)

type Home struct{}

func (Home) DescHelix() string { return "Install ~/.config/helix" }
func (Home) Helix() {
	api.SyncDir(api.Home(".config/helix"), paths.Dot+"/helix/*")
}

func (Home) DescGhostty() string { return "Install ~/.config/ghostty" }
func (Home) Ghostty() {
	api.SyncDir(api.Home(".config/ghostty"), paths.Dot+"/ghostty/*")
}

func (Home) DescHexai() string { return "Install ~/.config/hexai (Linux)" }
func (Home) WhenHexai(f api.Facts) bool { return f.GOOS == "linux" }
func (Home) Hexai() {
	api.SyncDir(api.Home(".config/hexai"), paths.Dot+"/hexai/*")
}

func (Home) DescTimesamurai() string { return "Install ~/.config/timesamurai" }
func (Home) Timesamurai() {
	api.SyncDir(api.Home(".config/timesamurai"), paths.Dot+"/timesamurai/*")
}

func (Home) DescLazygit() string { return "Install ~/.config/lazygit" }
func (Home) Lazygit() {
	api.SyncDir(api.Home(".config/lazygit"), paths.Dot+"/lazygit/*")
}

func (Home) DescOpencode() string { return "Install ~/.config/opencode" }
func (Home) Opencode() {
	api.SyncDir(api.Home(".config/opencode"), paths.Dot+"/opencode/*")
}

func (Home) DescAgents() string { return "Install agent command/skill symlinks" }
func (Home) Agents() {
	commands := paths.NotesPrompts + "/commands"
	skills := paths.NotesPrompts + "/skills"
	if _, err := os.Stat(commands); err != nil {
		return
	}

	for _, tool := range api.Elems(".cursor", ".claude", ".agents", ".opencode", ".pi", ".amp") {
		toolDir := api.Home(tool)
		api.EnsureDir(toolDir, WithMode(0o750))
		api.Link(toolDir+"/commands", WithSymlink(commands))
		api.Link(toolDir+"/skills", WithSymlink(skills))
	}

	codex := api.Home(".codex")
	api.EnsureDir(codex, WithMode(0o750))
	api.Link(codex+"/prompts", WithSymlink(commands))
}

func (Home) DescPrompts() string { return "Legacy alias for home_agents" }
func (Home) Prompts() {
	_ = api.Run("home_agents")
}

func (Home) DescScripts() string { return "Install ~/scripts" }
func (Home) Scripts() {
	api.SyncDir(api.Home("scripts"), paths.Dot+"/scripts/*", WithFileMode(0o750), WithPrune)
}

func (Home) DescSsh() string { return "Install ~/.ssh/config" }
func (Home) Ssh() {
	api.InstallFile(api.Home(".ssh/config"), paths.Dot+"/ssh/config", WithMode(0o600))
}

func (Home) DescBash() string { return "Install bash configuration" }
func (Home) Bash() {
	api.InstallFile(api.Home(".bash_profile"), paths.Dot+"/bash/bash_profile")
	api.InstallFile(api.Home(".bashrc"), paths.Dot+"/bash/bashrc")
}

func (Home) DescFish() string { return "Install fish conf.d symlink" }
func (Home) Fish() {
	api.Link(api.Home(".config/fish/conf.d"), WithSymlink(paths.Dot+"/fish/conf.d"))
}

func (Home) DescFishCompletions() string { return "Install fish completions" }
func (Home) FishCompletions() {
	api.SyncDir(api.Home(".config/fish/completions"), paths.Dot+"/fish/completions/*")
}

func (Home) DescGitsyncer() string { return "Install gitsyncer config symlink" }
func (Home) Gitsyncer() {
	api.Link(api.Home(".config/gitsyncer"), WithSymlink(paths.Dot+"/gitsyncer"))
}

func (Home) DescVale() string { return "Install ~/.vale.ini" }
func (Home) Vale() {
	api.InstallFile(api.Home(".vale.ini"), paths.Dot+"/vale.ini")
}

func (Home) DescTmux() string { return "Install ~/.config/tmux" }
func (Home) Tmux() {
	api.SyncDir(api.Home(".config/tmux"), paths.Dot+"/tmux/*")
}

func (Home) DescTmuxRocky() string { return "Append rocky tmux overrides when on rocky" }
func (Home) WhenTmuxRocky(f api.Facts) bool {
	return api.And(
		func(f api.Facts) bool { return f.GOOS == "linux" },
		func(f api.Facts) bool {
			return strings.Contains(strings.ToLower(f.Hostname), "rocky")
		},
	)(f)
}
func (Home) TmuxRocky() {
	line := "source-file ~/.config/tmux/tmux.rocky.conf"
	api.File(api.Home(".config/tmux/tmux.local.conf"), WithoutLine(line))
	api.File(api.Home(".config/tmux/tmux.conf"), WithLine(line))
}

func (Home) DescSway() string { return "Install sway and waybar config" }
func (Home) Sway() {
	api.SyncDir(api.Home(".config/sway/config.d"), paths.Dot+"/sway/config.d/*")
	api.SyncDir(api.Home(".config/waybar"), paths.Dot+"/waybar/*")
}

func (Home) DescGitconfig() string { return "Set global git config (Linux)" }
func (Home) WhenGitconfig(f api.Facts) bool { return f.GOOS == "linux" }
func (Home) Gitconfig() {
	api.GitGlobal(
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

func (Home) DescSignature() string { return "Install ~/.signature" }
func (Home) Signature() {
	api.InstallFile(api.Home(".signature"), paths.Dot+"/signature")
}

func (Home) DescCalendar() string { return "Install ~/.calendar from private repo" }
func (Home) Calendar() {
	if _, err := os.Stat(paths.DotPrivate); err != nil {
		return
	}
	api.SyncDir(api.Home(".calendar"), paths.DotPrivate+"/calendar/*")
}

func (Home) DescPipewire() string { return "Install pipewire high-res config" }
func (Home) Pipewire() {
	api.Dir(api.Home(".config/pipewire"), WithMode(0o750))
	api.InstallFile(api.Home(".config/pipewire/pipewire.conf"), paths.Dot+"/pipewire/pipewire.conf", WithMode(0o600))
}

func (Home) DescQuickedit() string { return "Manage ~/QuickEdit symlinks" }
func (Home) WhenQuickedit(f api.Facts) bool {
	return f.GOOS == "linux" || f.GOOS == "freebsd"
}
func (Home) Quickedit() {
	api.EnsureDir(api.Home("QuickEdit"), WithMode(0o700))
	api.SymlinkMap(api.Home("QuickEdit"),
		"data", api.Home("data"),
		"Documents", api.Home("Documents"),
		"dotfiles", api.Home("git/dotfiles"),
		"foo.zone-gemtext", api.Home("git/foo.zone-content/gemtext"),
		"Notes", api.Home("Notes"),
		"public-snippets", api.Home("git/conf/snippets"),
		"worktime", api.Home("git/worktime"),
	)
}

func (Home) DescSystemdUser() string { return "Install and enable systemd user units" }
func (Home) SystemdUser() {
	units := api.SyncDir(api.Home(".config/systemd/user"), paths.Dot+"/systemd-user/*")

	api.Command("systemctl", api.Elems("--user", "daemon-reload"),
		DependsOn(units),
		WithName("systemctl.daemon-reload"),
	)
	api.Command("systemctl", api.Elems("--user", "enable", "random-wallpaper.timer"),
		Unless("systemctl", api.Elems("--user", "is-enabled", "random-wallpaper.timer")),
		DependsOn(units),
		WithName("systemctl.enable.random-wallpaper"),
	)
	api.Command("systemctl", api.Elems("--user", "enable", "home-backup.timer"),
		Unless("systemctl", api.Elems("--user", "is-enabled", "home-backup.timer")),
		DependsOn(units),
		WithName("systemctl.enable.home-backup"),
	)
}

func (Home) DescTaskwarrior() string { return "Install ~/.taskrc (Taskwarrior 3.x)" }
func (Home) WhenTaskwarrior(f api.Facts) bool { return f.GOOS == "linux" }
func (Home) Taskwarrior() {
	api.InstallFile(api.Home(".taskrc"), paths.Dot+"/taskwarrior/taskrc")
}
