package tasks

import (
	"os"
	"path/filepath"
	"strings"

	"codeberg.org/snonux/dotfiles/gonf/internal/paths"
	. "github.com/snonux/gonf/api"
	. "github.com/snonux/gonf/api/options"
)

type Home struct{}

func (Home) DescHelix() string { return "Install ~/.config/helix" }
func (Home) Helix() {
	Dir(paths.Home+"/.config/helix",
		WithSourceGlob(paths.Dot+"/helix/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescGhostty() string { return "Install ~/.config/ghostty" }
func (Home) Ghostty() {
	Dir(paths.Home+"/.config/ghostty",
		WithSourceGlob(paths.Dot+"/ghostty/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescHexai() string { return "Install ~/.config/hexai (Linux)" }
func (Home) WhenHexai(f Facts) bool { return f.GOOS == "linux" }
func (Home) Hexai() {
	Dir(paths.Home+"/.config/hexai",
		WithSourceGlob(paths.Dot+"/hexai/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescTimesamurai() string { return "Install ~/.config/timesamurai" }
func (Home) Timesamurai() {
	Dir(paths.Home+"/.config/timesamurai",
		WithSourceGlob(paths.Dot+"/timesamurai/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescLazygit() string { return "Install ~/.config/lazygit" }
func (Home) Lazygit() {
	Dir(paths.Home+"/.config/lazygit",
		WithSourceGlob(paths.Dot+"/lazygit/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescOpencode() string { return "Install ~/.config/opencode" }
func (Home) Opencode() {
	Dir(paths.Home+"/.config/opencode",
		WithSourceGlob(paths.Dot+"/opencode/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescAgents() string { return "Install agent command/skill symlinks" }
func (Home) Agents() {
	commands := paths.NotesPrompts + "/commands"
	skills := paths.NotesPrompts + "/skills"
	if _, err := os.Stat(commands); err != nil {
		return
	}

	for _, tool := range Elems(".cursor", ".claude", ".agents", ".opencode", ".pi", ".amp") {
		toolDir := paths.Home + "/" + tool
		ensureAgentToolDir(toolDir)
		Link(toolDir+"/commands", WithSymlink(commands))
		Link(toolDir+"/skills", WithSymlink(skills))
	}

	codex := paths.Home + "/.codex"
	ensureAgentToolDir(codex)
	Link(codex+"/prompts", WithSymlink(commands))
}

// ensureAgentToolDir registers a Dir resource only when path is missing.
// Existing directories and symlinks-to-directories (e.g. ~/.pi -> ~/git/hypr/pi)
// are left alone so Link children can still be applied.
func ensureAgentToolDir(path string) {
	info, err := os.Stat(path)
	if err == nil && info.IsDir() {
		return
	}
	Dir(path, WithMode(0o750))
}

func (Home) DescPrompts() string { return "Legacy alias for home_agents" }
func (Home) Prompts() {
	_ = Run("home_agents")
}

func (Home) DescScripts() string { return "Install ~/scripts" }
func (Home) Scripts() {
	Dir(paths.Home+"/scripts",
		WithSourceGlob(paths.Dot+"/scripts/*"),
		WithMode(0o700),
		WithFileMode(0o750),
		WithPrune,
	)
}

func (Home) DescSsh() string { return "Install ~/.ssh/config" }
func (Home) Ssh() {
	File(paths.Home+"/.ssh/config",
		WithSource(paths.Dot+"/ssh/config"),
		WithMode(0o600),
	)
}

func (Home) DescBash() string { return "Install bash configuration" }
func (Home) Bash() {
	File(paths.Home+"/.bash_profile",
		WithSource(paths.Dot+"/bash/bash_profile"),
		WithMode(0o640),
	)
	File(paths.Home+"/.bashrc",
		WithSource(paths.Dot+"/bash/bashrc"),
		WithMode(0o640),
	)
}

func (Home) DescFish() string { return "Install fish conf.d symlink" }
func (Home) Fish() {
	Link(paths.Home+"/.config/fish/conf.d",
		WithSymlink(paths.Dot+"/fish/conf.d"),
	)
}

func (Home) DescFishCompletions() string { return "Install fish completions" }
func (Home) FishCompletions() {
	Dir(paths.Home+"/.config/fish/completions",
		WithSourceGlob(paths.Dot+"/fish/completions/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescGitsyncer() string { return "Install gitsyncer config symlink" }
func (Home) Gitsyncer() {
	Link(paths.Home+"/.config/gitsyncer",
		WithSymlink(paths.Dot+"/gitsyncer"),
	)
}

func (Home) DescVale() string { return "Install ~/.vale.ini" }
func (Home) Vale() {
	File(paths.Home+"/.vale.ini",
		WithSource(paths.Dot+"/vale.ini"),
		WithMode(0o640),
	)
}

func (Home) DescTmux() string { return "Install ~/.config/tmux" }
func (Home) Tmux() {
	Dir(paths.Home+"/.config/tmux",
		WithSourceGlob(paths.Dot+"/tmux/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescTmuxRocky() string { return "Append rocky tmux overrides when on rocky" }
func (Home) WhenTmuxRocky(f Facts) bool {
	return f.GOOS == "linux" && strings.Contains(strings.ToLower(f.Hostname), "rocky")
}
func (Home) TmuxRocky() {
	line := "source-file ~/.config/tmux/tmux.rocky.conf"
	File(paths.Home+"/.config/tmux/tmux.local.conf", WithoutLine(line))
	File(paths.Home+"/.config/tmux/tmux.conf", WithLine(line))
}

func (Home) DescSway() string { return "Install sway and waybar config" }
func (Home) Sway() {
	Dir(paths.Home+"/.config/sway/config.d",
		WithSourceGlob(paths.Dot+"/sway/config.d/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
	Dir(paths.Home+"/.config/waybar",
		WithSourceGlob(paths.Dot+"/waybar/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescGitconfig() string { return "Set global git config (Linux)" }
func (Home) WhenGitconfig(f Facts) bool { return f.GOOS == "linux" }
func (Home) Gitconfig() {
	EachKV(Elems(
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
	), func(key, val string) {
		Command("git", Elems("config", "--global", key, val),
			Unless("git", Elems("config", "--global", "--get", key), ExpectStdout(val)),
			WithName("git."+key),
		)
	})
}

func (Home) DescSignature() string { return "Install ~/.signature" }
func (Home) Signature() {
	File(paths.Home+"/.signature",
		WithSource(paths.Dot+"/signature"),
		WithMode(0o640),
	)
}

func (Home) DescCalendar() string { return "Install ~/.calendar from private repo" }
func (Home) Calendar() {
	if _, err := os.Stat(paths.DotPrivate); err != nil {
		return
	}
	Dir(paths.Home+"/.calendar",
		WithSourceGlob(paths.DotPrivate+"/calendar/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)
}

func (Home) DescPipewire() string { return "Install pipewire high-res config" }
func (Home) Pipewire() {
	Dir(paths.Home+"/.config/pipewire", WithMode(0o750))
	File(paths.Home+"/.config/pipewire/pipewire.conf",
		WithSource(paths.Dot+"/pipewire/pipewire.conf"),
		WithMode(0o600),
	)
}

func (Home) DescQuickedit() string { return "Manage ~/QuickEdit symlinks" }
func (Home) WhenQuickedit(f Facts) bool {
	return f.GOOS == "linux" || f.GOOS == "freebsd"
}
func (Home) Quickedit() {
	Dir(paths.Home+"/QuickEdit", WithMode(0o700))

	EachKV(Elems(
		"data", paths.Home+"/data/",
		"Documents", paths.Home+"/Documents//",
		"dotfiles", paths.Home+"/git/dotfiles/",
		"foo.zone-gemtext", paths.Home+"/git/foo.zone-content/gemtext//",
		"Notes", paths.Home+"/Notes/",
		"public-snippets", paths.Home+"/git/conf/snippets//",
		"worktime", paths.Home+"/git/worktime/",
	), func(name, target string) {
		linkPath := paths.Home + "/QuickEdit/" + name
		if _, err := os.Stat(filepath.Clean(target)); err != nil {
			// Target missing: drop a stale QuickEdit link rather than fail apply.
			NoLink(linkPath)
			return
		}
		Link(linkPath, WithSymlink(target))
	})
}

func (Home) DescSystemdUser() string { return "Install and enable systemd user units" }
func (Home) SystemdUser() {
	units := Dir(paths.Home+"/.config/systemd/user",
		WithSourceGlob(paths.Dot+"/systemd-user/*"),
		WithMode(0o700),
		WithFileMode(0o640),
	)

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

func (Home) DescTaskwarrior() string { return "Install ~/.taskrc (Taskwarrior 3.x)" }
func (Home) WhenTaskwarrior(f Facts) bool { return f.GOOS == "linux" }
func (Home) Taskwarrior() {
	File(paths.Home+"/.taskrc",
		WithSource(paths.Dot+"/taskwarrior/taskrc"),
		WithMode(0o640),
	)
}
