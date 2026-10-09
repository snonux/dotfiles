# f3s Physical Hosts (area index)

The four Beelink S12 Pro / Intel N100 f-hosts (f0–f3) running FreeBSD: hardware,
base OS, power, console access, and crash investigation. Host IPs are in the
[hub table](../SKILL.md#quick-reference-host-ips).

## When to Use

- Hardware, BIOS, Wake-on-LAN, or FreeBSD base-system questions on an f-host
- Powering hosts on/off, UPS behavior, the Shelly plugs, rack fans
- A host that will not boot, hangs on shutdown, comes back on its own, or boots slowly
- Reaching a console through a JetKVM, or a console stuck at 640x480
- Investigating a kernel panic or silent hang

## Topic Files

Hardware and base system:

- [Hardware](hosts/hardware.md) — Beelink S12 Pro specs, network switch, IPs, MAC addresses, Wake-on-LAN
- [FreeBSD Setup](hosts/freebsd-setup.md) — base OS install, release upgrades, slow SSH login / DNS, 15.0 and 15.1 breaking changes, packages, ZFS snapshot policy, coretemp
- [UPS & Power](hosts/ups-power.md) — APC BX750MI, gonf-managed apcupsd on f0 (USB) and f1/f2/f3 (net clients)
- [Shelly Plugs](hosts/shelly-plug.md) — two **Plug M Gen 3**: **shelly1** (`192.168.1.28`) rack fans (boot rc.d + `f3sctl fans` / power-sequence thermal guard); **shelly2** (`192.168.1.29`) f-host AC (`f3sctl ac` / `/ac` API, independent of power on/off); shared digest auth (`admin`) and secret **`/keys/shelly_plug.secret`** / **`~/.shelly_plug`**

Console and JetKVM:

- [JetKVM](hosts/jetkvm.md) — inventory: one per f-host, **DHCP IPs that can change** (identify by MAC `30:52:53:…`/device ID; discovery sweep documented; `.151/.158/.191/.198` on 2026-10-06), shared password in `~/.jetkvm`, HTTP login + WebRTC JSON-RPC, read-only health probe [`scripts/jetkvm-probe.py`](../scripts/jetkvm-probe.py), `.151` = f2 with no HDMI lock (open); the virtual USB drive that stalled every boot for ~6 minutes (fixed with a `UQ_MSC_IGNORE` quirk)
- [Console resolution](hosts/console-resolution.md) — FreeBSD 15.1 regressed the console to vga 640x480 (fix `efi_max_resolution="1080p"` in loader.conf); JetKVM only captures 1080p

Shutdown, power and boot:

- [Shutdown hang & safe reboot](hosts/shutdown-hang.md) — `rc.shutdown` 90s watchdog → single-user → un-wakeable by WoL, caused by slow bhyve k3s guest stop (**mitigated 2026-06-28**: `rcshutdown_timeout="300"` on f0/f1/f2; vm-bhyve 1.7.3 has no `stop_timeout` lever); root cause of the f1 recurrence (shutting the storage MASTER down first); the safe remote-reboot procedure (`vm stopall` then `reboot`)
- [Hosts power themselves back on](hosts/power-on-after-shutdown.md) — clean shutdown, then the host boots again 1–10 minutes later; rejected hypotheses, evidence, BIOS settings to check
- [Slow boot after a wake](hosts/slow-boot-ntpd.md) — ~14 min of ICMP-but-no-services caused by `ntpd_sync_on_start` (fixed 2026-08-09)

Crashes:

- [Kernel Panics & Hangs](hosts/kernel-panics.md) — where the dumps/logs are, decoding vmcores without debug symbols (`dmesg -M`, `nm`), boot timing via `kern.msgbuf_show_timestamp`; fleet-wide 15.1 ZFS-taskq panic signature (NULL IP / `sched_ule_sswitch+0x888`) = kstack VA/PA aliasing at boot mount/shutdown export, suspect N100 PCID/INVLPG erratum (fix plan: `vm.pmap.pcid_enabled=0`); the f1 2026-09-25 un-dumped hang

## Related Areas

- Guests running on these hosts: [bhyve VMs](vms.md)
- Disks, pools and thermal troubleshooting: [Storage](storage.md)
- Reaching the hosts from outside the LAN: [Network](network.md)
