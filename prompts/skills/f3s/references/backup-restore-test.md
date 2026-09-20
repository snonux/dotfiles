# Backup Restore Test Preparation

Ephemeral FreeBSD bhyve guest on **f3** used to practice backup restore. It is a
clone of the existing `freebsd` development VM, kept on the same LAN IP while
the source stays stopped.

## Current State (torn down 2026-09-20)

The `backuprestoretest` clone is **gone**. On f3, `vm list` should show only
`freebsd` (Stopped, `AUTO No`) and `rocky` (Stopped, `AUTO Yes`). Recreate with
the steps below when needed.

When the guest exists, it looks like this:

| Field | Value |
|-------|-------|
| FreeBSD host | `f3.lan.buetow.org` (SSH port **22**) |
| vm-bhyve name | `backuprestoretest` |
| Cloned from | `freebsd` (`zroot/bhyve/freebsd`) |
| Guest reachability | `freebsd.lan` / `192.168.1.139` (same IP as source; do **not** run both) |
| Source VM | `freebsd` — leave **Stopped**, `AUTO No` |
| Autostart | `No` (not in `vm_list`; `rocky` remains f3's default autostart) |
| Restore pool | `backup` — stripe of `nda1`+`nda2` (~398G), mountpoint **`/backup`** |

### Disks / pools (while the clone exists)

| Host file | Guest | Size | Role |
|-----------|-------|------|------|
| `disk0.img` | `nda0` | 20G | `zroot` (OS) |
| `disk1.img` | `nda1` | 100G | `backup` vdev (with `nda2`) |
| `disk2.img` | `nda2` | 300G | `backup` vdev (with `nda1`) |

Config: `/zroot/bhyve/backuprestoretest/backuprestoretest.conf`

Guest layout after prep:

```text
zroot   → / (and standard FreeBSD datasets)
backup  → /backup          (pool root)
backup/paul → /backup/paul (home git/go data from the clone)
```

`~/git` → `/backup/paul/git`, `~/go` → `/backup/paul/go`.

## Create / recreate

On f3 (login shell is tcsh — wrap in `sh -c '…'` for redirections):

```sh
doas vm list
# freebsd must be Stopped before cloning or starting the clone (same guest IP)

doas vm clone freebsd backuprestoretest
doas vm stop backuprestoretest   # if already started
doas vm add -d disk -t file -s 300G backuprestoretest
doas vm start backuprestoretest
```

`vm clone` assigns a new UUID/MAC; the guest disk still has static
`192.168.1.139`, so keep the original `freebsd` VM stopped.

`-t` on `vm add` is the **backing** type (`file` / `zvol` / `sparse-zvol`), not the
emulation type (that stays `nvme` in the conf).

### Guest: replace clone `zagent` with `backup` on both data disks

The source VM uses `zagent` on `nda1` only. For this test guest, destroy that and
stripe **both** data disks into one pool named `backup` mounted at `/backup`:

```sh
# optional: salvage anything under /zagent first
doas zpool destroy zagent
doas zpool create -f -m /backup backup nda1 nda2
doas zfs set compression=on backup
# optional datasets, e.g.:
# doas zfs create -o mountpoint=/backup/paul backup/paul
```

Confirm:

```sh
zpool list backup          # ~398G
zpool status backup        # nda1 + nda2
df -h /backup
```

## SCP / non-interactive SSH caveat

Guest login shell is **fish**. `~/.config/fish/conf.d/games.fish` runs
`games::colorscript` on every shell start unless disabled. That prints:

```text
No colorscripts installed. Go to:
 https://gitlab.com/dwt1/shell-color-scripts
```

…which breaks `scp` (`Received message too long …`). On the guest:

```sh
touch ~/.colorscript.disable
```

Longer-term: gate colorscript with `if status is-interactive` in the fish
dotfiles (see conf `dotfiles`).

## Useful commands

```sh
# host
ssh -p 22 paul@f3.lan.buetow.org
doas vm list
doas vm start backuprestoretest
doas vm stop backuprestoretest

# guest (while clone is running)
ssh paul@freebsd.lan          # or 192.168.1.139
ping -c3 192.168.1.139
scp recovery.git.tar freebsd.lan:.
df -h /backup
```

## Teardown (when the test is done)

On f3 (`ssh -p 22 paul@f3.lan.buetow.org`), login shell is tcsh — wrap pipelines
in `sh -c '…'` if needed:

```sh
doas vm stop backuprestoretest
# if still Running after a few seconds (ACPI can hang while locked):
doas vm poweroff -f backuprestoretest

doas vm destroy -f backuprestoretest
doas vm list   # backuprestoretest gone; leave freebsd Stopped
```

Notes:

- `vm stop` sends ACPI; wait until STATE is Stopped before `destroy`. If the
  guest stays Running / locked, use `vm poweroff -f` (not `vm stop -f` — that
  flag is not for `stop`).
- `vm destroy -f` removes the guest dataset under `zroot/bhyve/backuprestoretest`
  (conf + `disk0.img` / `disk1.img` / `disk2.img`). No guest-side
  `zpool destroy backup` is needed.
- Do **not** destroy `freebsd` itself; only the clone.
- Do **not** start `freebsd` after teardown unless you explicitly want it.

## Related

- [Rocky Linux VMs](rocky-linux-vms.md) — vm-bhyve on f-hosts; FreeBSD VM on f3
- [f3 Rocky VM](f3-rocky-vm.md) — f3 autostart policy (`rocky` vs stopped `freebsd`)
- [`f3s-storage`](../../f3s-storage/SKILL.md) — real backup / zrepl / USB pool procedures
