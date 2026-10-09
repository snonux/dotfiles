# f-hosts power themselves back on after a clean shutdown

## The f-hosts POWER THEMSELVES BACK ON after a clean shutdown (2026-08-09)

**Distinct from the [shutdown hang](shutdown-hang.md) — do not confuse them.** A hung host stays
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
- **Not shelly1 (rack fans).** f0 was observed up while shelly1 read
  `output:false`. (shelly2 is f-host AC — see `shelly-plug.md` — and was not
  in the picture for this investigation.)
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

**Partly answered on 2026-08-09: ICMP/TCP probing is NOT the trigger.** f2 was
powered off by `f3sctl power f2 off` at 21:18Z and stayed off for **9h12m**,
through many `f3sctl power status` calls — each of which pings it and TCP-dials
port 22 — before being woken deliberately by WoL. So ordinary unicast traffic
does not wake these boards, and neither Gogios nor f3sctl's own status probe is
keeping the fleet awake. That removes the "wake on link / any pattern"
hypothesis and leaves the RTC alarm, USB/HID wake, and AC/ErP settings.

It also shows the wake is **not** universal across the fleet: f2 sat powered
off for nine hours during the same night that f0, f1 and f3 each came back on
their own. Whatever the trigger is, it did not reach f2 — so compare f2's BIOS
against a host that does self-wake rather than assuming all four are identical.

**2026-08-09, caught live during a full cluster shutdown — it is f0, and only
f0.** In a single `f3sctl power off` run:

| host | powered off | came back |
|---|---|---|
| f1 | 10:31 | stayed off |
| f2 | 10:31 | stayed off |
| f0 | 10:34:25 | **10:35:10 — 45 seconds later** |

f1 and f2 sat powered off through the whole window. f0 came back on its own
before the job had even finished confirming the power-down. Its
`/var/log/apcupsd.events` now shows this a fifth time.

**Not the UPS cutting power.** `apcupsd.conf` has `KILLDELAY 0` and
`TIMEOUT 0`, so no killpower is issued, and the log holds no power-failure or
on-battery event — the `exiting, signal 15` / `startup succeeded` pairs are
just f0's own shutdown and boot being recorded. The events file is a boot log
here, not evidence of UPS action.

### Hypotheses tested and REJECTED (do not re-propose these)

Recorded so the same ground is not covered twice:

1. **Network/unicast wake** — rejected. f2 stayed powered off for 9h12m while
   being pinged and TCP-dialled on port 22 by every `f3sctl power status` call.
2. **UPS cutting and restoring power** — rejected. `apcupsd.conf` has
   `KILLDELAY 0` / `TIMEOUT 0`, and there are no power-failure or on-battery
   events. The `exiting, signal 15` / `startup succeeded` pairs in
   `apcupsd.events` are just f0's own shutdowns and boots.
3. **APC UPS USB cable asserting wake** — rejected by test. f0 was powered off
   with `f3sctl power f0 off` **with the UPS still plugged in** and stayed off.
4. **shelly1 (fans) switching causing a mains transient** — rejected twice. The
   fans and f0 are on **completely separate circuits with no interconnection**
   (only the UPS touches f0, over USB), and empirically f0 stayed off through a
   fans-off switch while already powered down.

### What the evidence actually says

f0 has only ever self-woken when it was powered off **as the last live host of
a cluster-wide run**, with f1 and f2 already down:

| run | f1/f2 at the time | f0 outcome |
|---|---|---|
| `power f0 off` (per-host) | **up** | stayed off |
| `power off` (cluster-wide) ×5 | **already down** | woke 45 s – 10 min later |
| fans switched off, f0 already down 35 min | down | stayed off |

No mechanism is established. The pattern is real but unexplained, and it has
survived four wrong theories — so treat further armchair hypotheses with
suspicion and get the BIOS on screen instead.

**Next step: read f0's BIOS via the JetKVM** (needs the web UI in a browser to
see the screen; which of the four JetKVMs is f0's is not mapped yet — see
[jetkvm.md](jetkvm.md)). Check `Wake system from S5` (RTC), `State After G3`, and USB wake, and
**compare them against f1 or f2**, which do not do this. Leave Wake-on-LAN
enabled — f3sctl depends on it.

**Cheap confirmation before touching BIOS:** with the rack down, wake f0 alone
and power it off alone while f1/f2 stay off. That reproduces "f0 powered off
while the others are down" with no fan switching involved, and separates the
pattern from the shutdown path entirely.

**BIOS settings to check via the JetKVM** (IPs in the [JetKVM inventory](jetkvm.md)), in
likely order:

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
