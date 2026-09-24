# Dotfiles deployment (gonf)

The dotfiles repo (`~/git/dotfiles`) deploys through its gonf module
(`~/git/dotfiles/gonf`, wrapper `~/git/dotfiles/gonf.sh`). Rex was retired on
2026-09-24; the former `Rexfile` in the dotfiles repo is gone.

```sh
# Deploy dotfiles (as paul, on rocky)
~/git/dotfiles/gonf.sh home
```

`home` is the aggregate of every `home_*` task. Tasks gated to other hosts or
OSes are skipped, and `./gonf.sh -list` only shows the tasks whose conditions
match the current host (so `home_tmux_rocky` is listed on rocky, not on earth).

**No gonf equivalent for `pkg_rocky`.** The dotfiles gonf module only has
`pkg_fedora` (gated to the Fedora profile); the Rocky package list of the
retired Rex task `pkg_rocky` was not ported. Install Rocky packages by hand as
root with `dnf install -y …` (see [tools.md](tools.md) for the list).

## Rocky-specific gonf task

| Task | Runs when | What it does |
|------|-----------|--------------|
| `home_tmux_rocky` | Linux and hostname contains `rocky` | Removes any stale `source-file ~/.config/tmux/tmux.rocky.conf` from `tmux.local.conf` and appends it to the **end** of `tmux.conf` so the red/orange colors win |

Historical: the Rex version of `home_tmux_rocky` also stripped the
`extended-keys-format` line for tmux 3.2a compatibility. The gonf task does not;
it is no longer needed because the shared `tmux.conf` no longer sets
`extended-keys-format` (only `extended-keys on`, available since tmux 3.2).
