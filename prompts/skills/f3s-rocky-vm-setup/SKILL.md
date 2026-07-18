---
name: f3s-rocky-vm-setup
description: Reference for the plain Rocky Linux 9 bhyve VM (host `rocky`, 192.168.1.123) running on f3. Covers SSH keys, local git server remotes, tooling (tmux, fish, amp, claude-code, pi, taskwarrior, Rex), zrepl replication, and restricted user privileges. Use when working on or replicating the rocky VM configuration. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# Rocky VM Setup Reference

The `rocky` VM is a plain Rocky Linux 9 bhyve guest on **f3** (LAN IP `192.168.1.123`, WireGuard `192.168.2.123`). It is **not** part of the k3s cluster and serves as a general-purpose build / dev / git client VM.

Parent infrastructure: see the [`f3s`](../f3s/SKILL.md) skill (f3 host, zrepl, bhyve, git server).

## When to Use

- Working on or replicating the `rocky` VM configuration
- SSH keys, git remotes, installed tooling, tmux/fish first-run setup
- User privileges and sudoers, Rex deployment, zrepl replication

## Reference Files

Detailed reference documentation is in the `references/` subfolder — load the one that matches the task:

- [Overview](references/overview.md) — VM role, SSH keys, `/etc/hosts` LAN aliases for all f3s hosts
- [Installed Tools](references/tools.md) — tool/version/install table, building taskwarrior 2.6.2 from source, first-run fish + fisher + Go tooling setup, tmux 3.2a compatibility note
- [Nested tmux](references/tmux.md) — `C-g` prefix on rocky vs `C-b` on earth, red/orange color scheme, source ordering, 256-color and truecolor (`COLORTERM`) passthrough
- [Git Remotes](references/git-remotes.md) — `r0`/`r1`/`r2` remotes replacing codeberg, `git@r{N}:30022`, repos pushed, authorized-keys secret
- [User and Privileges](references/privileges.md) — `root` full access; `paul` removed from `wheel`, NOPASSWD only for `update-coding-agents`, sudoers config
- [Scripts](references/scripts.md) — `/home/paul/scripts/update-coding-agents` (updates claude-code + pi)
- [Rex Usage](references/rex.md) — `rex pkg_rocky` (root) / `rex home` (paul), Rocky-specific `home_tmux_rocky` task
- [ZFS Snapshot / Replication](references/zrepl.md) — `zroot/bhyve/rocky` via zrepl on f3 → f2, retention; full config in `f3s` skill
- [Notes](references/notes.md) — `claude` wrapper must be a symlink not a shell script (fork bomb), Node.js 22 module, `amp` non-TTY panic

## Quick Reference

- Host: `rocky` / `192.168.1.123` (LAN), `192.168.2.123` (WireGuard)
- Parent: f3 (see `f3s` skill)
- Git remotes: `ssh://git@r0:30022/repos/REPO.git` (and r1, r2)
- tmux prefix: `C-g` (rocky inner) over `C-b` (earth outer)
- paul sudo: only `/home/paul/scripts/update-coding-agents`
- Replication: zrepl f3 → f2, every 10 min