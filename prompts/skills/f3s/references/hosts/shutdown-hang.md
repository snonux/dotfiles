# Shutdown hangs and the safe remote-reboot procedure

## Shutdown hangs → host stuck in single-user → un-wakeable by WoL

**Symptom:** a host "won't boot" / is unreachable in the morning; WoL does nothing.

**Cause:** on `shutdown -p`/`-r`, `rc.shutdown` exceeds the 90s `rcshutdown_timeout`,
so `init` logs "terminated abnormally, going to single user mode" and the host drops to
**single-user instead of powering off**. It stays powered on with no network/sshd, so
**Wake-on-LAN cannot wake it** (WoL only wakes a powered-off NIC). Recovery then needs a
console (JetKVM) or physical power-cycle.

Recurring and near-simultaneous on **f0/f1/f2** (powered down together via
`wol-f3s shutdown`). **f3 never hangs.** The differentiator: the `vm` rc script stops
guests with `vm stopall -f`, which waits for each bhyve guest to ACPI-power-off. The
k3s cluster guests (on f0/f1/f2) take ~45–92s to stop (k3s/containerd teardown) —
measured 92s once, over the 90s watchdog — while f3's plain Rocky guest stops in ~2s.

### ROOT CAUSE (2026-08-08): shutting the storage MASTER down FIRST wedges f1

The f1 hang is not random and not a watchdog problem — it is caused by the
**order** hosts are powered off in.

`wol-f3s` (and `f3sctl` before this was fixed) shut down **f0 first**, then f1,
then f2. f0 is the CARP storage MASTER, so powering it off fails the
`f3s-storage-ha` VIP (192.168.1.138) over to f1. f1's `carpcontrol.sh` MASTER
branch then starts `rpcbind`, `mountd`, `nfsd`, `nfsuserd` and restarts
`stunnel` — and roughly ten seconds later f1 is itself told to power off. It
goes down as a **freshly promoted, live NFS server**, with r2 still running and
able to reconnect through the VIP, and hangs in the final phase.

Timeline from f1's own `/var/log/messages`, 2026-08-08:

```
21:23:22  f0   shutdown[33782]: power-down by f3sctl      <- master goes first
21:23:30  f1   carp: 1@re0: MASTER -> INIT                <- f1 HAD taken the VIP
21:23:33  f1   shutdown[36445]: power-down by f3sctl      <- 11s later, f1 dies
21:23:35  f1   syslogd: exiting on signal 15              <- last line ever logged
          f1   (hangs here, stays powered on)
```

**f2 went down cleanly in the same run.** f2 is not in the CARP pair at all,
which is the differentiator — not zrepl, and not the k3s guest.

This matches the existing guidance in the safe remote-reboot procedure below, which already
says to reboot the storage MASTER **f0 last**. The tooling simply did not obey
it.

**Fix (f3sctl, 2026-08-08):** `inventory.ShutdownOrder()` orders the power
group so the storage master is powered off **last** (f1, f2, then f0), and a
unit test pins it. There is no reason to ever fail the VIP over to a host that
is about to be shut down.

### Earlier notes on the f1 recurrence (superseded by the root cause above)

During the first full `f3sctl power off` / `power on` cycle, **f1 hung again**
while f0 and f2 powered off cleanly and woke normally. Key differences from the
2026-06-28 case, which change the diagnosis:

- The guests were **already stopped** before `poweroff` was issued (f3sctl stops
  them itself, bounded, and refuses to power off while any bhyve survives). So
  this was not `vm stopall` overrunning anything.
- f1's `/var/log/messages` ends at `syslogd: exiting on signal 15` with **no
  watchdog message**. The hang is in the phase *after* syslogd exits — the
  final unmount / ZFS export / firmware power-down — so by construction nothing
  is logged. `rcshutdown_timeout=300` does not help here.
- f1 is the **zrepl receive (sink) side** for `f0_to_f1_nfsdata`, so it has ZFS
  state f0 and f2 do not. That is the most plausible differentiator and the
  first thing to look at next time.

**The host stayed powered on** (confirmed by the operator at the machine), which
is the whole problem: WoL only wakes a NIC that actually powered down, so f1 was
unreachable and unwakeable. Recovery was a **hard reset**. Afterwards etcd
recovered on its own and all three k3s nodes returned Ready with no intervention.

**Do not infer power state from the UPS.** During this incident `apcaccess` on
f0 read `LOADPCT 14.0` of `NOMPOWER 410` (~57W), which was mistakenly read as
"only two hosts are drawing power". A Beelink idling in a hung shutdown draws
little enough to disappear into that figure. The UPS cannot answer this
question; look at the machine, or at its JetKVM.

**Detection (added to f3sctl 2026-08-08):** `power off` now waits for each host
to stop answering ICMP after it accepts the shutdown, and fails loudly naming
any host still answering after 2 minutes. Previously the tool reported success
because the host *accepted* the command, and the failure only surfaced later
when a wake did nothing.

**Mitigation (APPLIED 2026-06-28 to f0/f1/f2):** `rcshutdown_timeout="300"` in
`/etc/rc.conf` (`sysrc rcshutdown_timeout=300`). Default was 90s. This gives
`vm stopall -f` enough time to finish the slow k3s-guest ACPI poweroff (observed
45–92s) before `init`'s watchdog would otherwise drop the host to single-user.

Confirmed root cause of an f0 incident on 2026-06-28: a `power-down by paul` at
22:49:30 hit the 90s watchdog at 22:51:00 (`rc.shutdown[...]: 90 second watchdog
timeout expired` → `init: /etc/rc.shutdown terminated abnormally, going to single
user mode`). The host stayed powered-on in single-user, so WoL could not wake it the
next morning and it needed a hard power-cycle.

**Note — no `stop_timeout` lever here:** these hosts run **vm-bhyve 1.7.3**, whose
`rc.d/vm` stop path is `vm stopall -f` → ACPI-kill all guests then `wait_for_pids`
(from `rc.subr`), which waits **indefinitely** for the bhyve processes to exit. That
version has **no per-guest `stop_timeout` / force-`bhyvectl --destroy` option**, so
raising `rcshutdown_timeout` is the only effective mitigation on 1.7.3. (If a guest
ever truly hangs and never ACPI-powers-off, even 300s won't help — but observed
worst case is ~92s.)

`f3sctl` avoids relying on that unbounded rc.d path (as `wol-f3s` did before it):
its `agent poweroff` verb sends the same two SIGTERM signals as vm-bhyve 1.7.3
(which requests guest ACPI shutdown), polls for up to 240 seconds, and only then
SIGKILLs any remaining bhyve PID. It cannot call `vm stopall` here because that
command itself waits indefinitely. It refuses to power off if a VM still appears
running. A forced stop is logged and warrants checking k3s/etcd health after the
next boot; SIGKILL can corrupt an in-flight etcd WAL, so this is a last resort
rather than the normal shutdown path.

The 240 s guest timeout must stay **below** `rcshutdown_timeout=300`, or the
watchdog fires first and drops the host to single-user — powered on, no
network, un-wakeable by WoL. That coupling is enforced in
`f3sctl/internal/agent/poweroff.go` (`vmShutdownTimeout`) and documented in
both places.

**Retested 2026-08-02:** f2 initially exceeded the 240-second guest timeout. The
Rocky guest had duplicate hard+soft mounts of `/data/nfs/k3svolumes`, caused by
the NFS monitor timer directly requiring (and therefore immediately starting) its
service during boot. After removing that race, shutdown still spent exactly 90
seconds unmounting the hard NFS mount because systemd stopped its localhost
stunnel transport concurrently. The durable fix in the `conf` repo orders k3s
after the NFS mount and the mount after stunnel; shutdown reverses that order:
k3s stops, NFS unmounts, then stunnel stops. The final f2 test reached Rocky
system power-off in about 3 seconds and did not use the forced bhyve fallback.
Persistent journals (256 MB cap) are now enabled on r0/r1/r2 for future diagnosis.

## Safe remote-reboot procedure for an f-host

Because a hung `rc.shutdown` can strand a host in single-user (recoverable remotely
only through that host's JetKVM — every host has one, but f2's has had no picture
since 2026-10-06, see [jetkvm.md](jetkvm.md)):

1. Gracefully stop guests first, outside the 90s watchdog: `doas vm stopall` (wait for
   `vm list` to show none `Running`). This also avoids an ungraceful guest kill.
2. Reboot with **`doas reboot`** (NOT `shutdown -r`): `reboot` bypasses the
   `rc.shutdown` watchdog path, so it cannot drop to single-user.
3. Poll for return, then verify `kenv efi_max_resolution` and the `VT(...)` log line.
4. Guests with `AUTO` start back on boot; a stale vm-bhyve `Locked` state clears on
   reboot.

Sequence multiple hosts **one at a time** (do storage MASTER **f0 last** — rebooting it
fails the `f3s-storage-ha` CARP VIP over to f1) so only one k3s node is down at once
(etcd quorum preserved). f1 is normally CARP BACKUP; f0 is MASTER.
