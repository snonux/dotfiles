# dotfiles

My dotfiles, deployed locally or over ssh with [gonf](https://github.com/snonux/gonf).

## Layout

| Dir | Contents |
|---|---|
| `bash/` | `bash_profile`, `bashrc` |
| `fish/` | `conf.d/`, `completions/` |
| `zsh/` | zsh config (no gonf task) |
| `ghostty/` | ghostty terminal config |
| `gitsyncer/` | gitsyncer config |
| `gonf/` | gonf recipes for this repo, see [gonf/README.md](gonf/README.md) |
| `helix/` | helix editor config |
| `hexai/` | hexai config |
| `lazygit/` | lazygit config |
| `opencode/` | opencode config |
| `pipewire/` | high-res `pipewire.conf` |
| `signature/` | mail signature (file) |
| `ssh/` | `~/.ssh/config` |
| `sway/`, `waybar/` | sway `config.d/`, waybar config |
| `systemd-user/` | raw user units: `home-backup`, `quicklog-drain` (service + timer) |
| `taskwarrior/` | `taskrc` |
| `timesamurai/` | timesamurai config |
| `tmux/` | `tmux.conf`, `tmux.local.conf`, `tmux.rocky.conf` |
| `scripts/` | installed to `~/scripts` |
| `prompts/` | agent commands and skills |
| `notes/` | dated review notes |
| `plans/` | dated plans and runbooks |
| `vale.ini` | vale config |

## Deploy

`gonf.sh` runs the recipes with `go run` from `gonf/`. Works from any cwd; relative path args resolve against `gonf/`.

```sh
./gonf.sh -list                    # all tasks
./gonf.sh -n home                  # dry-run
./gonf.sh home                     # every home_* task
./gonf.sh pkg_fedora               # Fedora packages (Fedora profile only)
./gonf.sh home_helix home_tmux     # single tasks
./gonf.sh -profile=freebsd home    # override profile detection
./gonf.sh push paul@rocky home     # remote: plan streamed over ssh
./gonf.sh push -- -p 2222 user@host home_tmux
```

`push` installs or upgrades gonf on the target first. `gonf` must be on the PATH of a non-interactive ssh session there.

## Tasks

Guards are serializable and evaluated on the destination (gonf >= v0.19.0), so a pushed plan honours the target's OS and profile. `-list` shows every task; one whose guard fails on this machine gets a `[destination-guarded: <guard>]` suffix (try `-profile=other -list`).

| Task | Does | Applies to |
|---|---|---|
| `home` | all `home_*` tasks | all |
| `home_agents` | links `commands/`, `skills/` of `~/Notes/Prompts` into `~/.cursor`, `~/.claude`, `~/.agents`, `~/.opencode`, `~/.amp`, `~/.pi` (if present); `~/.codex/prompts` | all; skipped if `~/Notes/Prompts` missing on controller |
| `home_bash` | symlinks `~/.bash_profile`, `~/.bashrc` | all |
| `home_calendar` | syncs `~/.calendar` from `~/git/conf_private/dotfiles/calendar` | all; skipped if that checkout is missing on controller |
| `home_fish` | symlinks `~/.config/fish/conf.d` | all |
| `home_fish_completions` | syncs `~/.config/fish/completions` | all |
| `home_ghostty` | syncs `~/.config/ghostty` | all |
| `home_gitconfig` | global git config (user, delta, difftastic, `hx` editor) | all |
| `home_gitsyncer` | symlinks `~/.config/gitsyncer` | all |
| `home_helix` | syncs `~/.config/helix` | all |
| `home_hexai` | syncs `~/.config/hexai` | Linux |
| `home_lazygit` | syncs `~/.config/lazygit` | all |
| `home_opencode` | syncs `~/.config/opencode` | all |
| `home_pipewire` | installs `~/.config/pipewire/pipewire.conf` (0600) | Linux |
| `home_prompts` | alias of `home_agents` | all |
| `home_quickedit` | `~/QuickEdit` symlinks to data, Documents, dotfiles, gemtext, Notes, snippets, worktime | profile fedora, rocky, freebsd, darwin |
| `home_scripts` | syncs `~/scripts` (0750, prunes removed files) | all |
| `home_signature` | installs `~/.signature` | all |
| `home_ssh` | installs `~/.ssh/config` (0600) | all |
| `home_sway` | syncs `~/.config/sway/config.d`, `~/.config/waybar` | Linux |
| `home_systemd_user` | user units + timers `home-backup`, `quicklog-drain`, generated `random-wallpaper` (hourly) | Linux |
| `home_taskwarrior` | installs `~/.taskrc` (Taskwarrior 3.x) | all |
| `home_timesamurai` | syncs `~/.config/timesamurai` | all |
| `home_tmux` | syncs `~/.config/tmux` | all |
| `home_tmux_rocky` | alias of `home_tmux` | all |
| `home_vale` | symlinks `~/.vale.ini` | all |
| `pkg_fedora` | installs the workstation package set, removes `Rex`; privileged | profile fedora |

Profile detection reads `/etc/os-release`; macOS reports `darwin`. FreeBSD has neither, so pass `-profile=freebsd`.

macOS works for a local run on the Mac and for `push you@mac home`: destination paths are recorded as `${HOME}/...` and expand to `/Users/<you>` there. There is no package or launchd backend, so `pkg_fedora` and `home_systemd_user` skip on a Mac. Symlink tasks (`home_bash`, `home_fish`, `home_gitsyncer`, `home_vale`, `home_agents`) point into `~/git/dotfiles` and `~/Notes/Prompts` on the destination, so a Mac needs those checkouts. lazygit on macOS reads `~/Library/Application Support/lazygit` unless `XDG_CONFIG_HOME` is set.

## Scripts

Installed by `home_scripts`. Quick hacks mostly.

| Script | Does |
|---|---|
| `ai` | editor AI prompt: `hx.hexai-prompt`, or `hx.nvim-copilot-prompt` on macOS |
| `audit-due` | lists git repos due for a code audit (churn since last `audit/<date>` tag) |
| `brokenlinkfinder` | crawls a site for broken links (Ruby) |
| `gvim` | opens helix in a new ghostty window (qutebrowser editor hook) |
| `home-backup` | rsyncs `$HOME` to a remote host, with excludes; run by the `home-backup` timer |
| `hx.prompt` | reads a prompt in a tmux split with helix |
| `hx.aichat-prompt`, `hx.chatgpt-prompt`, `hx.hexai-prompt`, `hx.nvim-copilot-prompt` | pipe an `hx.prompt` prompt to aichat, chatgpt, hexai or nvim Copilot |
| `hx.goformatter` | `goimports \| gofumpt` |
| `immich-export` | exports Immich assets per account and date range |
| `immich-upload` | uploads images to Immich, skipping SHA1 duplicates |
| `pihole-dns-toggle` | toggles Pi-hole DNS for the active NetworkManager connection |
| `quicklog-drain` | drains Quicklog notes from Garage into `~/Notes/Quicklog`; run by its timer |
| `randomnote.rb` | prints a random line from the foo.zone notes or a local book text |
| `random-wallpaper.sh` | sets a random GNOME wallpaper; run hourly by `random-wallpaper.timer` |
| `screenshot` | flameshot wrapper: `full`, `screen`, `gui` |
| `sideload-koreader` | installs a KOReader APK over adb |
| `stabilize-video` | 2-pass vidstab + 4K HEVC encode (VAAPI, libx265 fallback) |
| `temp-backup` | rsyncs `~/Syncthing/Notes`, `~/Documents` to `f0.wg0:tempbackup` |
| `tmux-cycle-a-session` | cycles tmux sessions named `A-*` (`next`/`prev`) |
| `wol-f3s` | wake-on-LAN / shutdown for f0-f3 and the Pis |

## Conventions

- `tmux/tmux.conf` ends with a `%if "#{m:*rocky*,#{host}}"` block that sources `tmux.rocky.conf` (prefix `C-g`, red/orange theme). Same file on every host, tmux picks the overrides. Needs tmux >= 3.0.
- `home_tmux_rocky` is only a legacy alias of `home_tmux`; old invocations keep working.
- `prompts/` holds agent `commands/*.md` and `skills/*/`. `~/Notes/Prompts` is a symlink to it, and `home_agents` links it into each agent tool. `prompts/sharable.md` lists the ones fit to share.
- Source root is `~/git/dotfiles`. From another worktree `gonf.sh` sets `GONF_DOTFILES_ROOT` to that checkout.

## More

- [gonf/README.md](gonf/README.md): recipe layout, adding tasks, build/test
- [notes/skills-review-2026-06-19.md](notes/skills-review-2026-06-19.md)
- [notes/agents-history-analysis-2026-06-19.md](notes/agents-history-analysis-2026-06-19.md)
- [plans/f3s-skill-split-plan.md](plans/f3s-skill-split-plan.md)
- [plans/immich-3x-upgrade-runbook.md](plans/immich-3x-upgrade-runbook.md): Immich 2.7 to 3.0 upgrade on f3s, done 2026-07-18
