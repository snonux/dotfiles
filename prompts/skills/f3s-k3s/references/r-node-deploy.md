# r-node Deploy Mechanism (gonf)

The reusable way to roll out files and systemd units to the three k3s Rocky
Linux VMs — **r0/r1/r2** — is a [gonf](https://github.com/snonux/gonf) task
in the conf repo's `gonf/` module. The canonical, fully-worked example is the
**`rnodes_nfs_mount_monitor`** task. Treat it as the template for *any* r-node
rollout; you do not need to re-derive the flow each time.

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

In the conf repo (`https://github.com/snonux/conf`):

```
gonf/rnodes/maintenance.go                # r-node tasks (Maintenance struct)
gonf/cluster/cluster.go                   # inventory: cluster rocky-k3s = r0, r1, r2
gonf/tasks/tasks.go                       # registers rnodes.Maintenance with prefix rnodes_
f3s/r-nodes/nfs-mount-monitor/            # source files the task installs
  check-nfs-mount.sh                      # → /usr/local/bin/
  k3s-nfs-drain.sh                        # → /usr/local/bin/
  nfs-mount-monitor.default               # → /etc/default/nfs-mount-monitor (tunables)
  nfs-mount-monitor.service / .timer      # → /etc/systemd/system/
  nfs-shutdown-marker.service             # → /etc/systemd/system/
  k3s-nfs-drain.service                   # → /etc/systemd/system/
  nfs-stunnel-ordering.conf               # → data-nfs-k3svolumes.mount.d/10-stunnel-ordering.conf
  k3s-nfs-ordering.conf                   # → k3s.service.d/10-nfs-ordering.conf
f3s/r-nodes/journald-persistent.conf      # used by rnodes_persistent_journal
```

The r-node tasks are `rnodes_nfs_mount_monitor`, `rnodes_persistent_journal`
and the aggregate `rnodes` (both); list them with `./gonf.sh -list | grep rnodes`.

## The deploy command

Run via conf's wrapper `./gonf.sh` (it works from any directory; the paths
below assume the **conf repo root**):

```sh
./gonf.sh cluster rocky-k3s rnodes_nfs_mount_monitor
```

This pushes to all three r-nodes at once (cluster `rocky-k3s`, parallelism 3).
Preview with `./gonf.sh cluster -n rocky-k3s rnodes_nfs_mount_monitor`.
To target a single node, push to it directly. A bare `push` does not take
the host's privilege mode from the inventory, so pass the inventory's
`-privilege=sudo` (the task is root-only); LAN hosts need `-p 22` because
`~/.ssh/config` maps `*.buetow.org` to port 2:

```sh
./gonf.sh push -n -privilege=sudo -- -p 22 root@r0.lan.buetow.org rnodes_nfs_mount_monitor   # preview
./gonf.sh push -privilege=sudo -- -p 22 root@r0.lan.buetow.org rnodes_nfs_mount_monitor
```

## How the pattern works (the reusable parts)

The inventory and the task struct establish conventions every r-node task
inherits:

- **`Cluster("rocky-k3s", r0, r1, r2).Parallel(3)`** in
  `gonf/cluster/cluster.go` — the three k3s VMs, reached as
  `root@rN.lan.buetow.org` port 22. The task body is wrapped in
  `WhenHostname(ClusterHosts(), …)` so it only applies on those hosts.
- **Root SSH.** The hosts are declared with `WithSSHUser("root")`: the
  `paul` user has no sudo on the r-nodes, and writing to `/usr/local/bin` and
  managing systemd both need root. Root SSH is pre-authorized via
  `authorized_keys`. The `Maintenance` struct embeds `RequiresRoot`; the
  hosts' `PrivilegeSudo` wraps that chunk in `sudo -n gonf apply`, which is
  a no-op elevation for root.
- **Registration.** `gonf/tasks/tasks.go` registers the struct with
  `RegisterMethods(rnodes.Maintenance{}, WithPrefix("rnodes_"), WithCluster(cluster.NameRockyK3s))`,
  so method `NFSMountMonitor` becomes task `rnodes_nfs_mount_monitor`.
- **Parallel 3** — all three nodes deploy concurrently. Safe because the
  tasks are idempotent and independent per node.
- **Source paths** resolve through `paths.RNodeAsset(...)` against the conf
  checkout (`~/git/conf`, or `GONF_CONF_ROOT` for another worktree), so they
  stay valid regardless of the current directory.

### Idempotent rollout flow

Inside the task, each file is declared with gonf's `InstallFile`:

```go
InstallFile("/usr/local/bin/check-nfs-mount.sh",
    paths.RNodeAsset(monitorDir+"/check-nfs-mount.sh"),
    WithMode(0o755), WithOwner("root"), WithGroup("root"))
```

gonf only writes a file when its **content or metadata actually differs**
from what's on the node — so re-running the task is a no-op when nothing
changed. All installed files feed one change fan-in:

```go
SystemdUnits(
    FanIn(inputs...),
    ActivateTimer("nfs-mount-monitor", WithRestart),
    ActivateServices(List("nfs-shutdown-marker", "k3s-nfs-drain")),
)
```

Only when a watched file changed does this run one `systemctl daemon-reload`
and one restart of `nfs-mount-monitor.timer`. Regardless of changes, the
timer and the `nfs-shutdown-marker` / `k3s-nfs-drain` services always
**converge** to enabled and active.

This split (reload/restart only on change, enable/start always) is the
pattern to copy: cheap, repeatable, and self-healing if a node drifted.

The task also pre-creates the state/output directories it needs
(`/var/lib/nfs-mount-monitor` mode 700,
`/var/lib/node_exporter/textfile_collector` mode 755, and the two systemd
drop-in directories) so the deployed files have somewhere to land.

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

- **Preview before applying.** `./gonf.sh cluster -n …` (or `push -n …`)
  shows what would change without touching the node.
- **Root, no sudo.** If a task errors on permission, check that the push went
  to `root@…` (the inventory user); `paul` has no sudo on the r-nodes.
- **Parallel 3 only works if tasks are idempotent and node-independent.**
  Keep new tasks that way, or lower the cluster's `.Parallel(n)` (or pass
  `cluster -j N`).
- **Adding a new file** to a deploy: add its `InstallFile` to
  `installNFSMountMonitorFiles` (or your task's fan-in list) so a
  reload/restart fires when it changes.

## Related

- The **behavior** of the deployed monitor (probes, fail-counter, cordon &
  auto-reboot escalation, alerting) is documented separately in
  [storage/nfs-mount-monitor.md](../../f3s-storage/references/nfs-mount-monitor.md). This file
  covers only the *deploy mechanism*; that one covers *what gets deployed*.
- Sibling gonf task groups in the conf repo (`gonf/garage/`, `gonf/frontends/`,
  `gonf/rocky/`) follow the same cluster/privilege/idempotent-`InstallFile`
  shape against different clusters (`garage`, `frontends`, `rocky-all`).
