---
name: rocky-vm-setup
description: Reference for the plain Rocky Linux 9 bhyve VM (host `rocky`, 192.168.1.123) running on f3. Covers SSH keys, local git server remotes, tooling (tmux, fish, amp, claude-code, pi, taskwarrior, Rex), zrepl replication, and restricted user privileges. Use when working on or replicating the rocky VM configuration.
---

# Rocky VM Setup Reference

The `rocky` VM is a plain Rocky Linux 9 bhyve guest on **f3** (LAN IP `192.168.1.123`, WireGuard `192.168.2.123`). It is **not** part of the k3s cluster and serves as a general-purpose build / dev / git client VM.

Parent infrastructure: see the [`f3s`](skills/f3s) skill (f3 host, zrepl, bhyve, git server).

---

## SSH Keys

| Key | Path | Purpose |
|-----|------|---------|
| Root VM key | `/root/.ssh/id_ed25519` | Git server SSH auth |
| Paul VM key | `/home/paul/.ssh/id_ed25519` | Git server SSH auth, local remotes |

The public keys are added to the k3s `git-server-authorized-keys` secret (namespace `cicd`) so both `root` and `paul` can push/pull via `git@r{N}:30022`.

```sh
# Regenerate if needed
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519 -C 'root@rocky.f3s.lan.buetow.org'
```

---

## /etc/hosts

Short LAN aliases for all f3s hosts (short, `.lan`, and `.lan.buetow.org` variants):

```
# f3s k3s node LAN aliases
192.168.1.120 r0 r0.lan r0.lan.buetow.org
192.168.1.121 r1 r1.lan r1.lan.buetow.org
192.168.1.122 r2 r2.lan r2.lan.buetow.org

# f3s FreeBSD host LAN aliases
192.168.1.130 f0 f0.lan f0.lan.buetow.org
192.168.1.131 f1 f1.lan f1.lan.buetow.org
192.168.1.132 f2 f2.lan f2.lan.buetow.org
192.168.1.133 f3 f3.lan f3.lan.buetow.org

# f3s Raspberry Pi LAN aliases
192.168.1.125 pi0 pi0.lan pi0.lan.buetow.org
192.168.1.126 pi1 pi1.lan pi1.lan.buetow.org
192.168.1.127 pi2 pi2.lan pi2.lan.buetow.org
192.168.1.128 pi3 pi3.lan pi3.lan.buetow.org
```

---

## Installed Tools

| Tool | Version | How Installed |
|------|---------|---------------|
| tmux | 3.2a | `dnf install -y tmux` |
| tmux prefix | C-g | **Rocky override** — nested tmux (see below) |
| fish | 3.7.1 | `dnf install -y fish` (EPEL) |
| amp | 0.7.1 | Downloaded binary from GitHub releases |
| claude-code | 2.1.169 | `npm install -g @anthropic-ai/claude-code` |
| pi coding agent | 0.79.0 | `npm install -g @earendil-works/pi-coding-agent` |
| taskwarrior | 2.6.2 | **Built from source** (see below) |
| Rex | 1.16.1 | `cpanm Rex` (requires expat-devel, perl-LWP-Protocol-https) |
| zoxide | 0.9.8 | `dnf install -y zoxide` (EPEL) |
| fzf | 0.58.0 | `dnf install -y fzf` (EPEL) |
| fzf fish plugin | — | **fisher install PatrickF1/fzf.fish** |
| ask, hexai*, gt, gitsyncer, etc. | — | `go install codeberg.org/snonux/...` (see update::tools) |

### Nested tmux (C-g on rocky)

Earth (outer tmux) uses the default **C-b** prefix. Rocky (inner tmux) uses **C-g** so you can control both layers.

**Visual distinction — you'll never confuse the two:**

| Layer | Prefix | Active Border | Status Bar | Pane Indicators |
|-------|--------|---------------|------------|-----------------|
| **Earth (outer)** | `C-b` | **Magenta** | White-on-purple | Default blue |
| **Rocky (inner)** | `C-g` | **Bright Red** | **Black-on-orange** with `[ROCKY]` label | **Red/orange** pane numbers, border labels |

**Workflow:**
| Key | Action |
|-----|--------|
| `C-b c` | Create window in outer tmux (earth) |
| `C-g c` | Create window in inner tmux (rocky) |
| `C-b b` | Send `C-b` through to inner tmux |
| `C-g g` | Send `C-g` through to inner-inner tmux |

Rocky config is in `~/.config/tmux/tmux.rocky.conf` and sourced from `tmux.local.conf`:

```sh
# ~/.config/tmux/tmux.rocky.conf
unbind C-b
set -g prefix C-g
bind C-g send-prefix

# Drastic RED/ORANGE color scheme
set -g pane-active-border-style 'fg=brightred,bold'
set -g status-style             'bg=colour208,fg=black,bold'
set -g status-left              ' [ROCKY] #[bg=brightred,fg=white] #S '
set -g window-status-current-style 'bg=brightred,fg=white,bold'
set -g window-status-style         'bg=colour208,fg=black'

# Active pane indicators
set -g display-panes-colour       colour208       # prefix+q pane numbers
set -g display-panes-active-colour brightred       # active pane number
set -g pane-border-status         top              # show pane info on borders
set -g pane-border-format         '#[fg=colour208] #{pane_index} #[fg=brightred]#{pane_title} '
set -g window-status-current-format ' #I*#[bg=brightred,fg=white] #W '
```

This is deployed by the `home_tmux_rocky` Rex task (runs only when `hostname =~ /rocky/`).

### Building taskwarrior from source

Rocky 9 does not ship `task`/`taskwarrior`. v3.x requires Rust; v2.6.2 compiles cleanly.

```sh
# deps
dnf install -y cmake gcc-c++ make libuuid-devel gnutls-devel libssh2-devel

# build
git clone --depth 1 --branch v2.6.2 \
  https://github.com/GothenburgBitFactory/taskwarrior.git /tmp/tw-build
cd /tmp/tw-build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)
cmake --install build

# verify
/usr/local/bin/task --version   # 2.6.2
```

### First-run fish setup

After the dotfiles `home` task deploys fish config, some plugins and binaries are expected but not yet present:

```sh
# 1. Install fisher (fish plugin manager)
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
fisher install jorgebucaran/fisher

# 2. Install the fzf.fish plugin (provides fzf_configure_bindings)
fisher install PatrickF1/fzf.fish

# 3. First-run taskwarrior creates ~/.taskrc
yes | task >/dev/null 2>&1

# 4. Install Go tooling binaries (run as paul)
for prog in ask hexai hexai-lsp-server hexai-tmux-action hexai-tmux-edit hexai-mcp-server; do
    go install codeberg.org/snonux/hexai/cmd/$prog@latest
done
for prog in tasksamurai timesamurai gt; do
    go install codeberg.org/snonux/$prog/cmd/$prog@latest
done
for prog in gitsyncer gos snonux; do
    go install codeberg.org/snonux/$prog/cmd/$prog@latest
done
# (foostore, loadbars, totalrecall, goprecords may need X11/GL deps for GUI — skip on headless)
```

**tmux 3.2a compatibility note:** The dotfiles `tmux.conf` includes `set -g extended-keys-format csi-u` (tmux 3.3+). On rocky this line is automatically stripped by the `home_tmux_rocky` Rex task. If you deploy manually, remove or comment out that line.

---

## User and Privileges

**`root`** — full root, used for package installs and Rex tasks.

**`paul`**
- **Removed from `wheel`** group. No general `sudo` access.
- **Only** allowed to run without password:
  ```
  /home/paul/scripts/update-coding-agents
  ```
- Home: `/home/paul`
- Git repos: `~/git/` (cloned via local `r0`/`r1`/`r2` remotes)

---

## Git Remotes

All repos available on the local git server have `r0`, `r1`, `r2` remotes replacing any codeberg ones:

```
url = ssh://git@r0:30022/repos/REPO.git
url = ssh://git@r1:30022/repos/REPO.git
url = ssh://git@r2:30022/repos/REPO.git
```

Repos pushed: conf, dotfiles, gemtexter, gitsyncer, goprecords, gt, hexai, hypr, ior, photoalbum, rcm, snonux, tasksamurai, wireguardmeshgenerator

---

## Scripts

`/home/paul/scripts/update-coding-agents`
```sh
#!/bin/sh
set -e
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi
echo "Updating Claude Code..."
npm update -g @anthropic-ai/claude-code @anthropic-ai/claude-code-linux-x64
echo "Updating pi coding agent..."
npm update -g @earendil-works/pi-coding-agent
echo "All coding agents updated."
```

Run as paul: `$ /home/paul/scripts/update-coding-agents`

---

## Rex Usage

The dotfiles repo (`~/git/dotfiles`) contains the main `Rexfile`.

```sh
# Install packages (as root)
rex pkg_rocky

# Deploy dotfiles (as paul)
rex home
```

`pkg_rocky` uses Rex's `pkg` directive which requires root — no `sudo` wrappers.

---

## ZFS Snapshot / Replication

The rocky VM dataset `zroot/bhyve/rocky` is managed by **zrepl** on the FreeBSD host f3. It is **not** included in local `zfs-periodic` snapshots.

| Property | Value |
|------------|-------|
| Snapshots | Every 10 minutes via zrepl (`zrepl_` prefix) |
| Replication | f3 → f2 (`zroot/sink/f3/zroot/bhyve/rocky`) |
| Retention | 10 immediate + 24 hourly + 14 daily |
| Local snap job | `zroot/bhyve/rocky` excluded from `local_zfs_snapshots` |

See [`f3s` skill zrepl.md](skills/f3s/references/storage/zrepl.md) for full config.

---

## Notes

- The `claude` wrapper must **not** be a shell script calling the JS wrapper — that caused a fork bomb because `cli-wrapper.cjs` tried to exec the `claude` binary but found the script instead. Use a direct symlink or the npm-installed binary.
- Node.js v20 is installed via `dnf module install nodejs:20/common`.
- `amp` panics in non-TTY environments — that's expected for a TUI editor.
