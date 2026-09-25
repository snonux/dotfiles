# Kernel Panics & Silent Hangs on f-hosts

How to investigate crashes on the FreeBSD f-hosts (f0–f3, Beelink S12 Pro /
Intel N100, FreeBSD 15.1-RELEASE-p2, GENERIC). Started 2026-09-25 after f1 was
found powered on but dark; see "Findings so far" before drawing conclusions.

Related, but different, failure modes (rule them out first):

| Looks like | Actually | Reference |
|---|---|---|
| Host up, no SSH, pings | ntpd blocking rc at boot (fixed) | [console-jetkvm-shutdown.md](console-jetkvm-shutdown.md) §2b |
| Host on after shutdown, WoL can't wake it | `rc.shutdown` 90 s watchdog → single-user | [console-jetkvm-shutdown.md](console-jetkvm-shutdown.md) §2 |
| f0 turns itself back on | self-wake, unexplained | [console-jetkvm-shutdown.md](console-jetkvm-shutdown.md) §2a |

## 1. Where the evidence is

SSH as `paul` on port 22 (`~/.ssh/config` maps `*.buetow.org` to port 2 for the
OpenBSD frontends). The login shell is csh-like, so pipe scripts into `sh`:
`ssh -p 22 paul@f1.lan.buetow.org sh < script.sh`.

| Evidence | Where | Notes |
|---|---|---|
| Crash dumps | `/var/crash/vmcore.N`, `info.N` | `dumpdev="AUTO"`, swap partition; `savecore` keeps 10, ~0.7–0.9 GB each |
| Panic text of the *previous* boot | `/var/log/messages` right after a `---<<BOOT>>---` | Survives only a warm reboot (panic → auto reboot). A cold power cycle loses it |
| Boot/shutdown times | `last -n 30 \| grep -E "boot\|shutdown"` | `boot time` is written late in rc, **not** kernel start |
| Real kernel start | `sysctl kern.boottime` | Compare with `boot time` to measure the rc stall |
| Was the host reachable? | other hosts' logs, e.g. f0 zrepl `dial tcp 192.168.2.131:8888: i/o timeout` | *timeout* = no network at all; *refused* = kernel up, service not |
| Messages log | `/var/log/messages*.bz2` | Rotates **hourly** (zrepl spam, >1000K) and keeps only 5, so about 5 h of history. Grab it early, and `grep -v 'zrepl\['` |

A panic **always** writes a dump and reboots after `kern.panic_reboot_wait_time=15`
s (no KDB backend is compiled in, so `debugger_on_panic=1` is a no-op). A
host that is dark with its power LED on and **no new vmcore** afterwards did
not have a normal panic. It is a hang: firmware, loader, kernel deadlock,
single-user mode, or a panic that could not dump. Only the screen tells
which, so look at the JetKVM (f1) or plug in HDMI **before** pressing power.

## 2. Reading the dumps

`gdb` (with `kgdb151`) is installed on f0–f3 (2026-09-25), but the **kernel
debug symbols are not** (`/usr/lib/debug/boot/kernel/kernel.debug` missing),
so `kgdb bt` fails and `crashinfo` says "Unable to find a kernel debugger".
What works without symbols:

```sh
# panic text straight out of each dump (uses the ELF symtab, not debug info)
for i in 0 1 2 3 4 5 6 7 8 9; do
  [ -f /var/crash/vmcore.$i ] || continue
  echo "== vmcore.$i $(doas grep Dumptime /var/crash/info.$i | cut -c14-)"
  doas dmesg -M /var/crash/vmcore.$i -N /boot/kernel/kernel |
    grep -E "Fatal trap|fault virtual|instruction pointer|current process|^#[0-9]|Uptime" | tail -10
done

# map an instruction pointer to a function (kernel range 0xffffffff80200000+;
# zfs.ko is a module, see `kldstat` for its load address)
nm -n /boot/kernel/kernel | awk '$1 <= "ffffffff80bbbd48"' | tail -1
```

The in-dump `kdb_backtrace` stops at `calltrap`, so the frames **below** the
trap are missing. Getting them needs the kernel debug symbols: install the
`kernel-dbg` distribution matching `15.1-RELEASE-p2`. **Ask the user first**,
since it is a system change of several hundred MB. Then run
`kgdb /boot/kernel/kernel /var/crash/vmcore.N` and use `bt` and `info registers`.

## 3. Timing the boot

`kern.msgbuf_show_timestamp="1"` is in `/boot/loader.conf` on f0–f3 (set
2026-09-25, backup `/boot/loader.conf.bak-20260925`). Every kernel message, and
all console output (rc steps, via `kern.log_console_output=1`), then carries a
`[uptime-seconds]` prefix from the first line of boot:

```sh
dmesg -a | less        # whole boot incl. rc output, timestamped
dmesg -a | grep -nE "^\[[0-9]+\]" | awk -F'[][]' '{d=$2-p; if (d>20) print "gap " d "s before: " $0; p=$2}'
```

This finds the ~6.5 min stall between kernel start and syslogd on f1 (see
below). It also shows what was running when a boot-time panic hit, because the
same timestamps are in the previous boot's msgbuf and in `dmesg -M vmcore.N`.

## 4. Findings (2026-09-25)

**Volume:** f0 has 10+ dumps, f1 10, f2 10+ (Aug 5 onwards) and f3 1. The
oldest ones have already rotated out. Every panic is either `Fatal trap 12:
page fault` or `Fatal trap 9: general protection fault`.

**One signature across all hosts:**
- `current process = 6` (zfskern) or `0`. The thread is always a **ZFS taskq
  thread**: `z_upgrade_N`, `z_prefetch_N`, `z_metaslab_N`, `z_zvol`, `z_zrele_N`,
  `z_unlinked_drain_N`, `dp_zil_clean_taskq_`, `dp_sync_taskq`,
  `dmu_objset_find_N`, `spa_async_thread`, `z_trim_iss_N`.
- The instruction pointer is always one of these:
  - `0x0`, with fault address `0x0`: a jump through a NULL function pointer.
  - `0xffffffff80bbbd48` = **`sched_ule_sswitch+0x888`**, the ULE context switch.
  - Garbage: `0x20`, `0x521`, `0x200000000`, `0x23e0fc398fb0`, `0x4113af078bc2`.
- **Reading:** a ZFS kernel thread is switched back in with a corrupted saved
  context or stack. That points at memory corruption (a kernel bug in 15.1 ZFS or
  the scheduler) or at the CPU/platform. It does not look like one bad DIMM,
  because four separate machines show the same fingerprint.
- **When:** many at uptime **5 s – 6m17s** (pool import, `zfs mount`, zvol
  minors at boot), and many at shutdown time. For example, f1 and f2 panicked
  one second apart on 2026-08-31 22:24:4x, during a cluster power-down.

**f1 incident 2026-09-25:**

| Time | Event |
|---|---|
| 00:39 | clean f3sctl power-down |
| ~11:06 | WoL. Panicked at 11:12, uptime 6m15s, `dmu_objset_find_3`, GPF at `sched_ule_sswitch+0x888`. Dumped and auto-rebooted |
| 11:21 | up |
| 11:41 | clean f3sctl power-down (`syslogd: exiting`) |
| 13:00 | f0/f2/f3 woken and up. f1 stayed dark (f0 zrepl i/o timeouts from 13:07) with its power LED **on** |
| ~20:12 | user pressed power. `kern.boottime` shows a **fresh** kernel start, not a resumed boot. syslogd and network only came up at 20:18 |

- **No vmcore for the dark period**, so it was not a normal panic, and which
  of these happened is still unknown:
  - the 11:41 shutdown never reached S5, or
  - the 13:00 WoL boot hung before the network came up.
- It "looked like the boot continued" after the button press only because
  f1's boot currently spends ~6.5 min before networking.

## 5. Root cause analysis (zj2, 2026-09-25)

**When:** every dump happens either right after `Mounting local filesystems:`
(boot, `zfs mount -a`) or right after `All buffers synced.` (shutdown, pool
export). None happen in steady state. The "Uptime 4h/12h" dumps are shutdowns
(f3sctl power-downs). Both moments create or destroy many ZFS taskq kthreads,
so kernel stacks are allocated and freed in bulk.

**What:** `sched_ule_sswitch+0x888` is the `retq` after `popq rbx,r12-r15,rbp`
(check with `llvm-objdump -d --start-address=0xffffffff80bbbd08`). A thread
coming back from `cpu_switch` pops its own stack frame and gets:
- a frame full of data: repeated 16-bit words, and once ASCII JSON (`e0acd7"}`), so GPF on the non-canonical return address, or
- a zeroed frame, so `ret` to `0` (IP=0 page fault).

**The key evidence** is in f0 vmcore.1/3 and f1 vmcore.0. There the dump shows
a *valid* `sched_switch` frame at the faulting `rsp`: a real `mi_switch`
return address, and no trap frame. But the CPU popped garbage from that address
and pushed its trap frame somewhere else. So the CPU's TLB mapped that kernel
stack VA to a different physical page than the page tables did. In the other
dumps (f0 vmcore.6, f2 vmcore.1/9) the page table itself points at a page that
holds file/ARC data. Either way it is **kernel stack VA/PA aliasing, which is
a stale TLB entry or a kernel stack page that was freed and reused**. It is
not a bad DIMM, which would not reproduce identically on 3 machines, and not a
ZFS logic bug, since ZFS only supplies the threads.

**Why f3 hardly panics:** wtmp has 90 shutdowns on f0 since Aug 1 but only 4
on f3. The panic rate is about 10 % per boot/shutdown cycle, and f3 is almost
never cycled. f3 also has half the datasets (24 vs 42-48) and no second pool
(zdata on ada1), so there is less kthread churn per cycle. f3's own dump
(`dom0`, `zone_release`, uptime 1d10h) is a different signature.

**Suspect:** Intel N100 = Alder Lake-N/Gracemont (CPUID 0xb06e0, model 0xbe).
It is on the list of CPUs where INVLPG does not flush *global* TLB entries
while PCID is enabled (Intel ADL erratum, and Linux disables PCID on it).
Kernel stack mappings are global. FreeBSD detects the problem
(`vm.pmap.pcid_invlpg_workaround=1`, `vm.pmap.pcid_enabled=1`), but the
symptom says some path still leaves stale entries. The alternative is a 15.x
kstack/thread-reap bug. Either way, the test below tells them apart.
No microcode package is loaded. `cpu-microcode-intel-20260512` is available,
and EN-26:20 (early-load bug) does **not** list 0xb06e0, so early loading
works on p2.

**Side finding:** the ~6 min boot stall is `Root mount waiting for: CAM`. The
JetKVM's virtual-media umass device (`umass0`, `<JetKVM USB Emulation
Device>`) fails INQUIRY with retries. It is unrelated to the panics.
To fix it, turn off JetKVM mass storage/virtual media, or unplug it.

Per-host panic tables: `/var/crash/panic-summary-2026-09.txt` on f0-f2. Only
the newest 2 vmcores per host were kept.

## 6. Fix plan (needs the user; nothing applied yet)

1. **`vm.pmap.pcid_enabled="0"` in `/boot/loader.conf` on f0-f3.** This is
   the discriminating test and the likely fix. With PTI off it costs almost
   nothing. Verify with `sysctl vm.pmap.pcid_enabled` after reboot. Expect 0
   panics over about 20 power cycles per host. Before, there were about 6-7
   in 60 cycles.
2. Microcode: `pkg install cpu-microcode-intel`, then add
   `cpu_microcode_load="YES"` and
   `cpu_microcode_name="/boot/firmware/intel-ucode.bin"`. Verify with
   `kldload cpuctl; cpucontrol -i 1 /dev/cpuctl0`, or dmesg `CPU microcode: updated`.
3. `freebsd-update install` to **15.1-RELEASE-p3** (available; kernel +
   hwpmc/krpc/sound; zfs.ko unchanged). This is hygiene, not the fix.
4. If panics continue with PCID off, it is a FreeBSD kstack bug. Install
   `kernel-dbg` for p3, get `bt` output, and file a PR with the
   "dump stack valid, registers garbage" evidence. Also consider stable/15.
5. Still useful: a hardware watchdog (`ichwd` + `watchdogd`) for the
   un-dumped hangs (f1 2026-09-25).

## 7. Open questions

1. On the next hang, screenshot the console via the JetKVM **before**
   touching power.
2. The f1 11:41 to 20:12 dark period is still unexplained (no vmcore).
