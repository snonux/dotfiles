# r-node Deploy Mechanism (Rex)

The reusable way to roll out files and systemd units to the three k3s Rocky
Linux VMs — **r0/r1/r2** — is a [Rex](https://www.rexify.org/) task. The
canonical, fully-worked example is the **`nfs_mount_monitor`** task. Treat it
as the template for *any* r-node rollout; you do not need to re-derive the
flow each time.

## Hosts: r0/r1/r2 vs f0/f1/f2

The r-nodes are Rocky Linux 9 bhyve guests, one per FreeBSD host:

| VM | LAN IP | Runs on f-host |
|----|--------|----------------|
| r0 | 192.168.1.120 | f0 (192.168.1.130) |
| r1 | 192.168.1.121 | f1 (192.168.1.131) |
| r2 | 192.168.1.122 | f2 (192.168.1.132) |

f3 is **not** part of this group — it is standalone bhyve and hosts the plain
`rocky` VM, not a k3s node. r-node deploys never touch f3.

## Where it lives

In the conf repo (`https://codeberg.org/snonux/conf`, dir `f3s/`):

```
f3s/r-nodes/Rexfile                       # deploy tasks for r0/r1/r2
f3s/r-nodes/nfs-mount-monitor/            # source files the task pushes
  check-nfs-mount.sh                      # → /usr/local/bin/
  nfs-mount-monitor.default               # → /etc/default/   (tunables)
  nfs-mount-monitor.service               # → /etc/systemd/system/
  nfs-mount-monitor.timer                 # → /etc/systemd/system/
```

## The deploy command

Run from the **conf repo root**:

```sh
rex -f f3s/r-nodes/Rexfile nfs_mount_monitor
```

This pushes to all three r-nodes at once. To target a single node, use Rex's
host filter, e.g. `rex -f f3s/r-nodes/Rexfile -H 192.168.1.120 nfs_mount_monitor`.

## How the pattern works (the reusable parts)

The Rexfile establishes conventions every r-node task inherits:

- **`group r_nodes => qw(192.168.1.120 192.168.1.121 192.168.1.122)`** — the
  three k3s VMs by LAN IP. Each `task` declares `group => 'r_nodes'`.
- **`user 'root'; sudo FALSE;`** — tasks connect as **root** over SSH. The
  `paul` user has no sudo on the r-nodes, and writing to `/usr/local/bin` and
  managing systemd both need root. Root SSH is pre-authorized via
  `authorized_keys`.
- **`parallelism 3;`** — all three nodes deploy concurrently. Safe because the
  tasks are idempotent and independent per node.
- **`$RNODES_DIR`** is resolved with `realpath($::rexfile)` so source-file
  paths stay valid regardless of CWD or Rex worker forking.

### Idempotent rollout flow

Inside the task, each file is deployed with Rex's `file` resource:

```perl
file '/usr/local/bin/check-nfs-mount.sh',
  source    => catfile($monitor_dir, 'check-nfs-mount.sh'),
  owner => 'root', group => 'root', mode => '755',
  on_change => sub { $changed = 1 };
```

Rex only writes a file when its **content actually differs** from what's on
the node — so re-running the task is a no-op when nothing changed. The
`on_change` handlers set a single `$changed` flag; only if something changed
does the task run:

```perl
run 'systemctl daemon-reload';
run 'systemctl restart nfs-mount-monitor.timer';
```

Finally — regardless of whether files changed — the task **converges** the
service state so the timer is always enabled and running:

```perl
service 'nfs-mount-monitor.timer', ensure => 'started';
run 'systemctl enable nfs-mount-monitor.timer';
```

This split (reload/restart only on change, enable/start always) is the
pattern to copy: cheap, repeatable, and self-healing if a node drifted.

The task also pre-creates the state/output directories it needs
(`/var/lib/nfs-mount-monitor` mode 700,
`/var/lib/node_exporter/textfile_collector` mode 755) so the deployed script
has somewhere to write.

## Verify after deploy

```sh
# On each r-node (over SSH as root) — confirm the timer is active & enabled:
systemctl status nfs-mount-monitor.timer

# Watch the service fire and log:
journalctl -u nfs-mount-monitor -f
```

What success looks like:

- `systemctl status …timer` reports **active (waiting)** and **enabled**, with
  a `Trigger:` line a few seconds out (the timer fires every 10 s).
- `journalctl -u nfs-mount-monitor` shows a fresh oneshot run roughly every
  10 s with no errors.

One-shot remote check from a roaming laptop (see
[remote-access.md](remote-access.md)):

```sh
ssh -A -J rex@fishfinger.buetow.org root@r0.wg0 \
  "systemctl is-active nfs-mount-monitor.timer && systemctl is-enabled nfs-mount-monitor.timer"
```

## Gotchas

- **Run from the conf repo root**, not from `f3s/r-nodes/` — the `-f` path in
  every example is repo-relative (`f3s/r-nodes/Rexfile`).
- **Root, no sudo.** If a task errors on permission, it's almost always that
  the connection fell back to `paul` (who has no sudo here). The Rexfile sets
  `user 'root'` for exactly this reason.
- **`parallelism 3` only works if tasks are idempotent and node-independent.**
  Keep new tasks that way, or lower the parallelism.
- **Adding a new file** to a deploy: give it `on_change => sub { $changed = 1 }`
  so a reload/restart fires when it changes, and place it before the
  `if ($changed)` block.

## Related

- The **behavior** of the deployed monitor (probes, fail-counter, cordon &
  auto-reboot escalation, alerting) is documented separately in
  [storage/nfs-mount-monitor.md](../../f3s-storage/references/nfs-mount-monitor.md). This file
  covers only the *deploy mechanism*; that one covers *what gets deployed*.
- There are sibling Rexfiles in the conf repo (`f3s/garage/Rexfile`,
  `frontends/Rexfile`) that follow the same group/user/idempotent-`file`
  shape against different host groups.
