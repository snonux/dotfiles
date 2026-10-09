# f3s rocky VM (area index)

The `rocky` VM is a plain Rocky Linux 9 bhyve guest on **f3** (LAN IP `192.168.1.123`, WireGuard `192.168.2.123`). It is **not** part of the k3s cluster and serves as a general-purpose build / dev / git client VM.

Parent infrastructure: the f3 host ([Physical hosts](hosts.md)), bhyve ([bhyve VMs](vms.md)), zrepl ([Storage](storage.md)), and the git server ([Workloads — Forgejo](workloads/forgejo.md)).

## When to Use

- Working on or replicating the `rocky` VM configuration
- SSH keys, git remotes, installed tooling, tmux/fish first-run setup
- User privileges and sudoers, gonf dotfiles deployment, zrepl replication

## Topic Files

Load the one that matches the task:

- [f3 Rocky VM (bhyve side)](rocky-vm/f3-rocky-vm.md) — the guest as seen from f3: current state table, vm-bhyve autostart policy, VM config, root SSH
- [Overview](rocky-vm/overview.md) — VM role, SSH keys (incl. Forgejo key), `/etc/hosts` LAN aliases for all f3s hosts
- [Installed Tools](rocky-vm/tools.md) — tool/version/install table, building taskwarrior 2.6.2 from source, first-run fish + fisher + Go tooling setup, tmux 3.2a compatibility note
- [Nested tmux](rocky-vm/tmux.md) — `C-g` prefix on rocky vs `C-b` on earth, red/orange color scheme, source ordering, 256-color and truecolor (`COLORTERM`) passthrough
- [Git Remotes](rocky-vm/git-remotes.md) — Forgejo remotes (`code.f3s.buetow.org:2022`), passphrase-less `id_ed25519_forgejo` + SSH `Host` pin; server-side user in [Workloads — Forgejo](workloads/forgejo.md#rocky-push-access)
- [User and Privileges](rocky-vm/privileges.md) — `root` access, Paul's targeted updater and IOR sudo rules, sudoers config
- [Scripts](rocky-vm/scripts.md) — the `update::tools` Fish updater and its privileged commands
- [Dotfiles deployment (gonf)](rocky-vm/gonf.md) — `~/git/dotfiles/gonf.sh home` (paul), rocky tmux overrides loaded by `tmux.conf` itself (`home_tmux_rocky` is a legacy alias of `home_tmux`); no Rocky package task (install packages with `dnf` as root)
- [ZFS Snapshot / Replication](rocky-vm/snapshot-replication.md) — `zroot/bhyve/rocky` via zrepl on f3 → f2, retention; full config in [Storage — zrepl](storage/zrepl.md)
- [Notes](rocky-vm/notes.md) — `claude` wrapper must be a symlink not a shell script (fork bomb), Node.js 22 module, `amp` non-TTY panic

## Quick Reference

- Host: `rocky` / `192.168.1.123` (LAN), `192.168.2.123` (WireGuard)
- Parent: f3
- Git remotes: `ssh://git@code.f3s.buetow.org:2022/snonux/REPO.git` (key: `id_ed25519_forgejo`)
- tmux prefix: `C-g` (rocky inner) over `C-b` (earth outer)
- paul sudo: exact updater commands plus existing IOR development rules; see [privileges](rocky-vm/privileges.md)
- Replication: zrepl f3 → f2, every 10 min
