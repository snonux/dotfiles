package home

import (
	"github.com/snonux/dotfiles/gonf/paths"
	"github.com/snonux/dotfiles/gonf/system"
	. "github.com/snonux/gonf/api"
)

// HomeTasks contains tasks that manage unprivileged resources under $HOME.
type HomeTasks struct{}

// Notes ensures ~/Notes exists.
//
// Notes creates the directory only when missing (EnsureDir). An existing
// directory or a symlink to one — earth's Syncthing vault link — is left
// alone. Other tasks (home_agents, home_quickedit, quicklog) expect this path.
func (HomeTasks) Notes() {
	EnsureDir(DestHome("Notes"), WithMode(0o755))
}

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
	if !OptionalControllerDir(paths.NotesPrompts("commands"), "home_agents") {
		return
	}
	if !OptionalControllerDir(paths.NotesPrompts("skills"), "home_agents") {
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
//
// Tree sync includes nested production helpers, but leaves tests and the
// quicklog e2e tree repo-only. Exclusions preserve destination paths, so
// NoFile still removes the previously installed quicklog e2e wrapper.
func (HomeTasks) Scripts() {
	scripts := Dir(DestHome("scripts"), WithSource(paths.Dot("scripts")),
		WithMode(0o700), WithFileMode(0o750), WithPrune,
		WithExclude("tests", "quicklog", "quicklog-drain-e2e"))
	// Sync quicklog separately so the main tree never changes its 0750 mode.
	Dir(DestHome("scripts/quicklog"), WithSource(paths.Dot("scripts/quicklog")),
		WithMode(0o750), WithFileMode(0o750), WithPrune,
		WithExclude("e2e"), DependsOn(scripts))
	NoFile(DestHome("scripts/quicklog-drain-e2e"))
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

// Fish installs fish conf.d symlink and plugin functions.
//
// Fish links conf.d into the checkout and syncs fish/functions (fzf.fish
// plugin bindings) into ~/.config/fish/functions without pruning other
// local function files.
func (HomeTasks) Fish() {
	EnsureDir(DestHome(".config/fish"), WithMode(0o750))
	Symlink(DestHome(".config/fish/conf.d"), paths.DestDot("fish/conf.d"))
	SyncDir(DestHome(".config/fish/functions"), paths.Dot("fish/functions/*"))
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
// Mac keeps its own global git config. The negated guard travels in the
// plan and is checked on the destination.
func (HomeTasks) OptsGitconfig() TaskOptions {
	return TaskOptions{WhenNotOS("darwin")}
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
	if !OptionalControllerDir(calendar, "home_calendar") {
		return
	}
	SyncDir(DestHome(".calendar"), calendar+"/*")
}

func (HomeTasks) OptsPipewire() TaskOptions {
	return TaskOptions{WhenLinux(), WhenHostnameContains("earth")}
}

// Pipewire installs pipewire high-res config (Linux, hostname earth).
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
//
// home-backup is removed on every Linux host. quicklog-drain and
// random-wallpaper are installed only when the hostname contains "earth".
func (HomeTasks) SystemdUser() {
	NoSystemdTimer("home-backup", WithUser)

	WhenHostname("earth", func() {
		units := SyncDir(DestHome(".config/systemd/user"), paths.Dot("systemd-user/quicklog-drain.*"))
		quicklogDrain := InstallFile(DestHome("scripts/quicklog-drain"), paths.Dot("scripts/quicklog-drain"), WithMode(0o750))
		// Standalone task: timer must not activate until both the thin
		// wrapper and scripts/quicklog/drain exist, even without home_scripts.
		// Dir first: atomicfile CreateTemp needs the parent (Pipewire pattern).
		Dir(DestHome("scripts/quicklog"), WithMode(0o750))
		quicklogDrainImpl := InstallFile(DestHome("scripts/quicklog/drain"), paths.Dot("scripts/quicklog/drain"), WithMode(0o750))
		// Only the unit files fan into the reload; the quicklog-drain script
		// is an ordering dependency of its timer, so editing it does not reload.
		SystemdUnits(
			WithUserBus(),
			FanIn(units),
			ActivateTimer("quicklog-drain", DependsOn(quicklogDrain, quicklogDrainImpl)),
		)
		// Generated timer (units mode 0644); shares the user-bus reload when
		// declared after SystemdUnits in this same when-fragment.
		SystemdTimer("random-wallpaper",
			WithUser,
			WithCommand("%h/scripts/random-wallpaper.sh"),
			WithOnCalendar("hourly"),
			WithPersistent,
			WithDescription("Set random GNOME wallpaper once per hour"),
			WithServiceDescription("Set random GNOME wallpaper from image directory"),
		)
	})
}

func (HomeTasks) OptsGoprecordsUpload() TaskOptions {
	// Needs system_uptimed so daemon + upload stay one apply on earth/zen.
	return TaskOptions{WhenLinux(), WhenHostnameIn("earth", "zen"), Needs(system.System.Uptimed)}
}

// GoprecordsUpload installs the hourly uptimed upload to goprecords (earth, zen).
//
// GoprecordsUpload installs the POSIX upload client under ~/.local/bin and the
// matching user systemd oneshot+timer. earth also runs the Mac/worktime
// mega-m3-pro import (second ExecStart). Needs system_uptimed (daemon half of
// the pair). Tokens stay out of git: ~/.config/goprecords-upload-<host>/token.
func (HomeTasks) GoprecordsUpload() {
	EnsureDir(DestHome(".local/bin"), WithMode(0o755))
	script := InstallFile(DestHome(".local/bin/goprecords-upload-client.sh"),
		paths.Dot("scripts/goprecords-upload-client.sh"), WithMode(0o750))

	WhenHostname("earth", func() {
		EnsureDir(DestHome(".config/goprecords-upload-earth"), WithMode(0o700))
		svc := InstallFile(DestHome(".config/systemd/user/goprecords-upload-earth.service"),
			paths.Dot("systemd-user/goprecords-upload-earth.service"), WithMode(0o644))
		tmr := InstallFile(DestHome(".config/systemd/user/goprecords-upload-earth.timer"),
			paths.Dot("systemd-user/goprecords-upload-earth.timer"), WithMode(0o644))
		SystemdUnits(WithUserBus(), FanIn(svc, tmr),
			ActivateTimer("goprecords-upload-earth", DependsOn(script)))
		NoSystemdTimer("goprecords-upload-zen", WithUser)
	})

	WhenHostname("zen", func() {
		EnsureDir(DestHome(".config/goprecords-upload-zen"), WithMode(0o700))
		svc := InstallFile(DestHome(".config/systemd/user/goprecords-upload-zen.service"),
			paths.Dot("systemd-user/goprecords-upload-zen.service"), WithMode(0o644))
		tmr := InstallFile(DestHome(".config/systemd/user/goprecords-upload-zen.timer"),
			paths.Dot("systemd-user/goprecords-upload-zen.timer"), WithMode(0o644))
		SystemdUnits(WithUserBus(), FanIn(svc, tmr),
			ActivateTimer("goprecords-upload-zen", DependsOn(script)))
		NoSystemdTimer("goprecords-upload-earth", WithUser)
	})
}

// Taskwarrior installs ~/.taskrc (Taskwarrior 3.x).
func (HomeTasks) Taskwarrior() {
	InstallFile(DestHome(".taskrc"), paths.Dot("taskwarrior/taskrc"))
}
