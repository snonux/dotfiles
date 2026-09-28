# dotfiles

My dotfiles, deployed locally or over ssh with [gonf](https://github.com/snonux/gonf).

## Layout

| Dir | Contents |
|---|---|
| `bash/` | `bash_profile`, `bashrc` |
| `fish/` | `conf.d/`, `completions/`, `functions/` (fzf.fish plugin) |
| `zsh/` | zsh config (no gonf task) |
| `ghostty/` | ghostty terminal config |
| `gitsyncer/` | gitsyncer config |
| `gonf/` | gonf recipes for this repo, see [gonf/README.md](gonf/README.md) |
| `helix/` | helix editor config |
| `hexai/` | hexai config |
| `lazygit/` | lazygit config |
| `opencode/` | opencode config |
| `opendoas/` | `/etc/doas.conf` (`permit nopass :wheel`) for Fedora |
| `pipewire/` | high-res `pipewire.conf` (earth only) |
| `uptimed/` | `uptimed.conf` template (`LOG_MAXIMUM_ENTRIES=0`) for earth and zen |
| `signature/` | mail signature (file) |
| `ssh/` | `~/.ssh/config` |
| `sway/`, `waybar/` | sway `config.d/`, waybar config |
| `systemd-user/` | raw user units: `quicklog-drain` (earth), `goprecords-upload-{earth,zen}`; `home-backup` legacy (removed by gonf) |
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
./gonf.sh home                     # unprivileged home configuration
./gonf.sh -privilege=sudo home_goprecords_upload # upload timer and its system_uptimed prerequisite (earth/zen)
./gonf.sh pkg_opendoas             # opendoas on every Fedora host
./gonf.sh pkg_fedora               # Fedora workstation packages (Fedora profile only)
./gonf.sh -privilege=sudo system_hosts system_wireguard system_uptimed system_fish_shell
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
| `home` | unprivileged `home_*` configuration; excludes `home_goprecords_upload` | all |
| `home_agents` | links `commands/`, `skills/` of `~/Notes/Prompts` into `~/.cursor`, `~/.claude`, `~/.agents`, `~/.opencode`, `~/.amp`, `~/.pi` (if present); `~/.codex/prompts` | all; skipped if `~/Notes/Prompts` missing on controller |
| `home_bash` | symlinks `~/.bash_profile`, `~/.bashrc` | all |
| `home_calendar` | syncs `~/.calendar` from `~/git/conf_private/dotfiles/calendar` | all; skipped if that checkout is missing on controller |
| `home_fish` | symlinks `~/.config/fish/conf.d`, syncs `~/.config/fish/functions` (fzf.fish plugin) | all |
| `home_fish_completions` | syncs `~/.config/fish/completions` | all |
| `home_ghostty` | syncs `~/.config/ghostty` | all |
| `home_gitconfig` | global git config (user, delta, difftastic, `hx` editor) | all but macOS |
| `home_goprecords_upload` | hourly user timer uploading uptimed stats to goprecords; Needs `system_uptimed`; earth also imports mega-m3-pro | Linux, hostname earth or zen |
| `home_gitsyncer` | symlinks `~/.config/gitsyncer` | all |
| `home_helix` | syncs `~/.config/helix` | all |
| `home_hexai` | syncs `~/.config/hexai` | Linux |
| `home_lazygit` | syncs `~/.config/lazygit` | all |
| `home_notes` | ensures `~/Notes` exists (creates only when missing) | all |
| `home_opencode` | syncs `~/.config/opencode` | all |
| `home_pipewire` | installs `~/.config/pipewire/pipewire.conf` (0600) | Linux, hostname earth |
| `home_prompts` | alias of `home_agents` | all |
| `home_quickedit` | `~/QuickEdit` symlinks to data, Documents, dotfiles, gemtext, Notes, snippets, worktime | profile fedora, rocky, freebsd, darwin |
| `home_scripts` | syncs `~/scripts` (0750, prunes removed files) | all |
| `home_signature` | installs `~/.signature` | all |
| `home_ssh` | installs `~/.ssh/config` (0600) | all |
| `home_sway` | syncs `~/.config/sway/config.d`, `~/.config/waybar` | Linux |
| `home_systemd_user` | removes `home-backup` timer; on hostname earth installs `quicklog-drain` and generated `random-wallpaper` (hourly) | Linux |
| `home_taskwarrior` | installs `~/.taskrc` (Taskwarrior 3.x) | all |
| `home_timesamurai` | syncs `~/.config/timesamurai` | all |
| `home_tmux` | syncs `~/.config/tmux` | all |
| `home_tmux_rocky` | alias of `home_tmux` | all |
| `home_vale` | symlinks `~/.vale.ini` | all |
| `pkg_fedora` | installs the workstation package set, removes `Rex`; privileged | profile fedora |
| `pkg_fish_tools` | installs `fzf` and `zoxide`; privileged | profile fedora |
| `pkg_helix` | installs `helix` (`hx`); privileged | profile fedora |
| `pkg_opendoas` | installs `opendoas` and `/etc/doas.conf` (`permit nopass :wheel`); privileged | profile fedora |
| `pkg_taskwarrior` | installs Taskwarrior 3.x (`task`); privileged | profile fedora |
| `system_fish_shell` | installs `fish`, sets paul's login shell to `/usr/bin/fish`; privileged | hostname earth, zen or rocky |
| `system_hosts` | owns the `# BEGIN GONF fleet` block of `/etc/hosts` (LAN + wg0 mesh rows), 0644 root:root; lines outside the block stay; privileged | hostname earth |
| `system_uptimed` | installs `uptimed`, deploys `/etc/uptimed.conf`, enables the daemon; privileged | hostname earth or zen |
| `system_wireguard` | `/etc/wireguard` 0700, existing `wg0.conf`/`wg1.conf` 0600 root:root; never content or units; privileged | hostname earth |

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
| `home-backup` | rsyncs `$HOME` to a remote host, with excludes; manual (timer removed by `home_systemd_user`) |
| `hx.prompt` | reads a prompt in a tmux split with helix |
| `hx.aichat-prompt`, `hx.chatgpt-prompt`, `hx.hexai-prompt`, `hx.nvim-copilot-prompt` | pipe an `hx.prompt` prompt to aichat, chatgpt, hexai or nvim Copilot |
| `hx.goformatter` | `goimports \| gofumpt` |
| `immich-export` | exports Immich assets per account and date range |
| `immich-upload` | uploads images to Immich, skipping SHA1 duplicates |
| `pihole-dns-toggle` | toggles Pi-hole DNS for the active NetworkManager connection |
| `quicklog-drain` | imports Quicklog notes from Garage S3 directly into taskwarrior (no local staging); run by its timer; `scripts/quicklog-drain-e2e` tests the whole pipeline against a sandbox. Deploy note: `fish/conf.d` is a live symlink (applies immediately) while this script and the systemd units are gonf copies — deploy both together via `./gonf.sh home`, otherwise the import preflight warns about notes stranded in `~/Notes/Quicklog` |
| `randomnote.rb` | prints a random line from the foo.zone notes or a local book text |
| `random-wallpaper.sh` | sets a random GNOME wallpaper; run hourly by `random-wallpaper.timer` (earth only) |
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
