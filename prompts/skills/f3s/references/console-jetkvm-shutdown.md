# Console (HDMI/JetKVM) & Shutdown Behavior on f-hosts

Findings from troubleshooting f1 on 2026-06-27, after the FreeBSD **15.1** upgrade
(`@pre-15.1-upgrade` ZFS snapshots, taken 2026-06-19/06-20). Applies to the Beelink
S12 Pro / Intel N100 hosts **f0, f1, f2, f3**.

A JetKVM (KVM-over-IP) is currently attached to **f1** (USB + HDMI). It enumerates on
the FreeBSD USB bus as `ugen0.X: <Multifunction Composite Gadget Linux Foundation>`
(idVendor `0x1d6b`, idProduct `0x0104`, iManufacturer `JetKVM`) — 3× HID interfaces
(keyboard/tablet/mouse) + 1× mass storage (virtual media). The generic "Composite
Gadget" product string means a name-grep for "JetKVM" can miss it; match on the gadget
descriptor instead.

## 1. HDMI / console regressed to 640x480 in FreeBSD 15.1 (breaks JetKVM)

**Symptom:** JetKVM shows no HDMI signal from a host.

**Cause:** FreeBSD 15.1's stock `/boot/defaults/loader.conf` ships
`efi_max_resolution="1x1"` (uncommented) and it is not overridden in
`/boot/loader.conf`. Capped at 1x1, the loader cannot hand off a usable EFI GOP
framebuffer, so `vt(4)` falls back from `efifb` to the legacy **`vga`** backend at
**640x480**. No `drm-kmod`/`i915kms` is loaded on any host, so nothing reinitializes
the GPU afterward. Proven on f2, whose logs span the upgrade:
`VT(efifb): resolution 1920x1080` (FreeBSD 14) → `VT(vga): resolution 640x480` (15.1).

**Fix (applied to all f-hosts 2026-06-27):** add to `/boot/loader.conf`:
```
efi_max_resolution="1080p"
```
Effective on next reboot → restores `VT(efifb): resolution 1920x1080`. Verify with:
```
kenv efi_max_resolution
grep -F 'VT(' /var/log/messages | tail -1
```

### Resolution / JetKVM capture notes
What this particular JetKVM locks onto from the firmware's static GOP framebuffer
(no KMS, so timings are firmware-defined and non-standard):

| `efi_max_resolution` | console backend | JetKVM result |
|---|---|---|
| (15.1 default `1x1`) | `vga` 640x480 | **no signal** |
| `1080p` | `efifb` 1920x1080 | **signal OK** (the one that works) |
| `720p` | `efifb` 1280x720 | **no signal** |

So **use `1080p`** — 720p produced no signal at all. A transient flicker / "no signal"
after changing modes was cleared by **rebooting the JetKVM device itself** (it caches
EDID/sync), not by changing the host. If 1080p still flickers, suspect the HDMI
cable/seating, or install `drm-kmod` + load `i915kms` for proper KMS (clean
EDID-negotiated timings + hotplug) — not yet done; bigger change on a headless host.

**Each host's resolution depends on ITS JetKVM's emulated EDID, not just loader.conf.**
All four hosts have a JetKVM attached and identical `efi_max_resolution="1080p"`, yet
only **f1** negotiates efifb 1920x1080; f0/f2/f3 fall back to `vga 640x480`. The firmware
GOP builds its mode list from the EDID the JetKVM presents, and **f1's JetKVM advertises
a 1080p-capable EDID while f0/f2/f3's only advertise up to 640x480** (no KMS driver to
override). This is a per-JetKVM **EDID configuration** difference, NOT something a reboot
changes: f1 came up 1080p on its first 1080p boot, *before* its JetKVM was ever rebooted
(that later JetKVM reboot only cleared a flicker). Verified 2026-06-27: rebooting the f3
*host* twice (JetKVM untouched) stayed 640x480.

**To make a host do 1080p:** set/raise that host's JetKVM emulated **EDID/resolution to
1080p** in the JetKVM web UI to match f1 — a host reboot alone does nothing. Alternative
host-side fix that is EDID-independent: install `drm-kmod` + load `i915kms` (Intel KMS),
which drives the output itself regardless of the firmware GOP/EDID — not yet done; bigger
change on headless hosts.

## 2. Shutdown hangs → host stuck in single-user → un-wakeable by WoL

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

## 2a. The f-hosts POWER THEMSELVES BACK ON after a clean shutdown (2026-08-09)

**Distinct from the hang below — do not confuse them.** A hung host stays
powered on and never answers ping. This is the opposite: the host powers off
correctly, then boots again on its own 1–10 minutes later.

Evidence from f0's `/var/log/apcupsd.events` over one evening, every entry a
`f3sctl power off` followed by an unattended restart:

```
21:23:27 shutdown -> 21:24:46 startup   (79s)
22:15:10 shutdown -> 22:19:02 startup   (4 min)
22:30:47 shutdown -> 22:36:05 startup   (5 min)
00:02:42 shutdown -> 00:12:23 startup   (10 min)
```

Four for four. Confirmed on **f0, f1 and f3** by `sysctl kern.boottime`; f0 and
f2 once booted within the *same second* of each other, which argues for a shared
trigger rather than four independently flaky boards.

Ruled out:

- **Not the UPS / AC.** `apcaccess` shows `STATUS: ONLINE`, `NUMXFERS: 0`,
  `TONBATT: 0` — the UPS never transferred. No power event happened.
- **Not the Shelly plug.** It drives only the rack fans; f0 was observed up
  while the plug read `output:false`.
- **Not the OS arming a wake.** Every wake sysctl is 0 on a running host:
  `dev.re.0.wake`, `dev.xhci.0.wake`, `dev.pci.1.wake`, `dev.hdac.0.wake`.
  Whatever does this is below the OS, in firmware.

Hardware: AMI BIOS **ADLNV105** (12/12/2023), board `MINI S`, Beelink S12 Pro
(Intel N100). Every host has a **JetKVM** attached, which enumerates as
`ugen0.x: <Multifunction Composite Gadget Linux Foundation>` — a USB HID
composite device, and therefore a candidate S5 wake source.

**Leading hypothesis, not yet proven:** a firmware wake source broader than
"magic packet only" — either wake-on-LAN triggered by ordinary unicast/ARP
traffic, or USB wake from the JetKVM's HID gadget. Note that anything probing a
powered-off host (Gogios `check_ping` every 5 min, and `f3sctl`'s own status
probe, which pings and TCP-dials port 22 on every API request) would then keep
waking the fleet.

**Decisive test not yet run:** power one host off and send it *nothing* — no
ping, no TCP, no API status call — for 15+ minutes. If it stays off, the wake
is network-traffic-driven; if it still boots, it is an RTC alarm or an
AC/ErP setting.

**BIOS settings to check via the JetKVM** (two are on the LAN:
`http://192.168.1.191/` and `http://192.168.1.198/`), in likely order:

1. `Advanced → ACPI Settings → Wake system from S5` (RTC alarm) — should be
   **Disabled**. A fixed-time alarm would produce regular restarts.
2. `Chipset → PCH-IO → Wake on LAN` / `PCIE Wake` — must be magic-packet only,
   not "wake on link" or "wake on any pattern". **f3sctl needs WoL to work, so
   this must stay enabled, just narrowed.**
3. `Advanced → USB Configuration → USB wake support` / `S4/S5 USB wake` —
   **Disable**, since the JetKVM's HID gadget can otherwise assert wake.
4. `Chipset → PCH-IO → State After G3` (restore on AC loss) — should be
   **Power Off** / **S5**, not "Power On" or "Last State".
5. `Advanced → Power → Deep Sleep / ErP` — enabling Deep S5 cuts standby rails
   to most devices and disables the broader wake sources, but **it also
   disables Wake-on-LAN from S5**, so this is a last resort.

Until this is fixed, the fleet cannot be kept powered off, and `f3sctl power
off` will keep reporting hosts as "did not complete shutdown" when they in fact
shut down cleanly and came back.

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

This matches the existing guidance in section 3 of this document, which already
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

`wol-f3s` now avoids relying on that unbounded rc.d path: it sends the same two
SIGTERM signals as vm-bhyve 1.7.3 (which requests guest ACPI shutdown), polls for
up to 240 seconds, and only then SIGKILLs any remaining bhyve PID. It cannot call
`vm stopall` here because that command itself waits indefinitely. The script
refuses to power off if a VM still appears running. A forced stop is logged in the
command output and warrants checking k3s/etcd health after the next boot; SIGKILL
can corrupt an in-flight etcd WAL, so this is a last resort rather than the normal
shutdown path.

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

## 3. Safe remote-reboot procedure for an f-host

Because a hung `rc.shutdown` can strand a host in single-user (unrecoverable remotely
unless the JetKVM is attached — it lives on f1 only):

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
