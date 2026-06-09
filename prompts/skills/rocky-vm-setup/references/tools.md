# Installed Tools

| Tool | Version | How Installed |
|------|---------|---------------|
| tmux | 3.2a | `dnf install -y tmux` |
| tmux prefix | C-g | **Rocky override** — nested tmux (see [tmux.md](tmux.md)) |
| fish | 3.7.1 | `dnf install -y fish` (EPEL) |
| helix | 25.07.1 | `dnf install -y helix helix-themes` (EPEL) |
| amp | 0.7.1 | Downloaded binary from GitHub releases |
| claude-code | 2.1.169 | `npm install -g @anthropic-ai/claude-code` |
| pi coding agent | 0.79.0 | `npm install -g @earendil-works/pi-coding-agent` |
| taskwarrior | 2.6.2 | **Built from source** (see below) |
| Rex | 1.16.1 | `cpanm Rex` (requires expat-devel, perl-LWP-Protocol-https) |
| zoxide | 0.9.8 | `dnf install -y zoxide` (EPEL) |
| fzf | 0.58.0 | `dnf install -y fzf` (EPEL) |
| fzf fish plugin | — | **fisher install PatrickF1/fzf.fish** |
| ask, hexai*, gt, gitsyncer, etc. | — | `go install codeberg.org/snonux/...` (see update::tools) |

## Building taskwarrior from source

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

## First-run fish setup

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

## tmux 3.2a compatibility note

The dotfiles `tmux.conf` includes `set -g extended-keys-format csi-u` (tmux 3.3+). On rocky this line is automatically stripped by the `home_tmux_rocky` Rex task. If you deploy manually, remove or comment out that line.
