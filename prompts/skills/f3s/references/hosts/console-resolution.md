# Console resolution on the f-hosts (FreeBSD 15.1 regression)

Findings from troubleshooting f1 on 2026-06-27, after the FreeBSD **15.1** upgrade
(`@pre-15.1-upgrade` ZFS snapshots, taken 2026-06-19/06-20). Applies to the Beelink
S12 Pro / Intel N100 hosts **f0, f1, f2, f3**.

## HDMI / console regressed to 640x480 in FreeBSD 15.1 (breaks JetKVM)

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

**Update 2026-10-06: all four hosts now boot `VT(efifb): resolution 1920x1080`**
(f0/f1/f2 booted that day, f3 on 2026-10-02), so the 640x480 fallback described above
is no longer the state of the fleet. Three JetKVMs capture 1080p; f2's does not, for a
different reason (see [jetkvm.md](jetkvm.md)).

**To make a host do 1080p:** set/raise that host's JetKVM emulated **EDID/resolution to
1080p** in the JetKVM web UI to match f1 — a host reboot alone does nothing. Alternative
host-side fix that is EDID-independent: install `drm-kmod` + load `i915kms` (Intel KMS),
which drives the output itself regardless of the firmware GOP/EDID — not yet done; bigger
change on headless hosts.
