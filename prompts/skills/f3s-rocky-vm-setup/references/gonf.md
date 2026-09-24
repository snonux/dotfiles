# Dotfiles deployment (gonf)

The dotfiles repo (`~/git/dotfiles`) deploys through its gonf module
(`~/git/dotfiles/gonf`, wrapper `~/git/dotfiles/gonf.sh`).

```sh
# Deploy dotfiles (as paul, on rocky)
~/git/dotfiles/gonf.sh home
```

`home` is the aggregate of every `home_*` task. OS, profile and hostname
guards are evaluated on the destination (gonf v0.19.0+), so pushing from earth
(`~/git/dotfiles/gonf.sh push paul@rocky home`) includes exactly the tasks
that apply on rocky, and a local run skips tasks gated to other hosts.
`./gonf.sh -list` marks tasks whose guard does not hold on the machine running
it with `[destination-guarded: <guard>]`.

**No Rocky package task.** The dotfiles gonf module only has `pkg_fedora`
(gated to the Fedora profile). Install Rocky packages by hand as root with
`dnf install -y …` (see [tools.md](tools.md) for the list).

## Rocky-specific tmux overrides

There is no rocky-only gonf task any more. The synced `tmux.conf` ends with

```tmux
%if "#{m:*rocky*,#{host}}"
source-file ~/.config/tmux/tmux.rocky.conf
%endif
```

so tmux itself loads the red/orange overrides where the hostname contains
`rocky`, and `home_tmux` converges on every host. `home_tmux_rocky` remains
only as a legacy alias of `home_tmux`. The shared `tmux.conf` only sets
`extended-keys on`, which rocky's tmux 3.2a supports.
