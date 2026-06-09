# Rex Usage

The dotfiles repo (`~/git/dotfiles`) contains the main `Rexfile`.

```sh
# Install packages (as root)
rex pkg_rocky

# Deploy dotfiles (as paul)
rex home
```

`pkg_rocky` uses Rex's `pkg` directive which requires root — no `sudo` wrappers.

## Rocky-specific Rex tasks

| Task | Runs when | What it does |
|------|-----------|--------------|
| `home_tmux_rocky` | `hostname =~ /rocky/` | Sources `tmux.rocky.conf` at the **end** of `tmux.conf` so red/orange colors win |
| `pkg_rocky` | Manually (as root) | Installs packages: tmux, fish, helix, zoxide, fzf, golang, nodejs, etc. |

The `home_tmux_rocky` task also cleans stale references from `tmux.local.conf` and strips the `extended-keys-format` line for tmux 3.2a compatibility.
