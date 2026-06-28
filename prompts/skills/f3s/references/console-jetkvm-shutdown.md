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
