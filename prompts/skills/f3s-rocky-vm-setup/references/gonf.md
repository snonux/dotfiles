# Dotfiles deployment (gonf)

The dotfiles repo (`~/git/dotfiles`) deploys through its gonf module
(`~/git/dotfiles/gonf`, wrapper `~/git/dotfiles/gonf.sh`). Rex was retired on
2026-09-24; the former `Rexfile` in the dotfiles repo is gone.

```sh
# Deploy dotfiles (as paul, on rocky)
~/git/dotfiles/gonf.sh home
```

`home` is the aggregate of every `home_*` task. Tasks gated to other OSes are
skipped, and `./gonf.sh -list` only shows the tasks whose conditions match the
controller (the host running `gonf.sh`). Pushing from earth
(`~/git/dotfiles/gonf.sh push paul@rocky home`) works the same way.

**No gonf equivalent for `pkg_rocky`.** The dotfiles gonf module only has
`pkg_fedora` (gated to the Fedora profile); the Rocky package list of the
retired Rex task `pkg_rocky` was not ported. Install Rocky packages by hand as
root with `dnf install -y …` (see [tools.md](tools.md) for the list).

## Rocky-specific tmux overrides

There is no rocky-only gonf task any more. The synced `tmux.conf` ends with

```tmux
%if "#{m:*rocky*,#{host}}"
source-file ~/.config/tmux/tmux.rocky.conf
%endif
```

so tmux itself loads the red/orange overrides where the hostname contains
`rocky`, and `home_tmux` converges on every host. `home_tmux_rocky` remains
only as a legacy alias of `home_tmux`. The former task appended the
`source-file` line after `home_tmux` had synced `tmux.conf`, so the two tasks
rewrote the file on every apply, and `home` pushed from earth dropped it
(its hostname guard was evaluated on the controller).

Historical: the Rex version of `home_tmux_rocky` also stripped the
`extended-keys-format` line for tmux 3.2a compatibility. That is no longer
needed: the shared `tmux.conf` only sets `extended-keys on` (tmux 3.2+).
