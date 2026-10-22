---
name: clean-ram-swap
description: "Investigate and reduce Linux RAM and swap usage, trace large processes to live coding agents, and remove verified stale temporary artifacts. Use when explicitly asked to clean RAM, clean swap, investigate memory pressure, or find orphaned agent processes."
disable-model-invocation: true
---

# Clean RAM and Swap

Diagnose the local Linux machine, identify what is still in use, and reclaim
memory from verified leftovers. This skill is manual-only. An investigation
request authorizes read-only diagnosis; a cleanup request also authorizes
removing identified disposable artifacts. Respect any narrower user scope.

## Measure actual pressure

Capture a baseline and repeat the relevant measurements after cleanup:

```sh
hostname
uptime
free -h
swapon --show
cat /proc/pressure/memory
vmstat 1 5
zramctl
df -h /tmp /dev/shm
findmnt -T /tmp
```

Use `MemAvailable`, memory PSI, and the interval rows of `vmstat` to distinguish
capacity use from active pressure. The first `vmstat` row is a since-boot
average. Low free RAM or full swap alone does not establish thrashing. Check
kernel and systemd-oomd journals for OOM kills when accessible.

Read `/proc/meminfo` for anonymous memory, shared memory and slab. For zram,
report both logical swap occupancy and actual physical RAM use (`zramctl`
TOTAL or `/sys/block/zram0/mm_stat`); these are not additional disk usage.
tmpfs contents consume RAM or swap and need not appear in a process's VmSwap.

## Attribute processes to sessions

Rank RSS and VmSwap from `/proc/*/status`. Where readable, use
`/proc/PID/smaps_rollup` Pss and SwapPss to avoid double-counting shared pages.
Do not treat VSZ or configured JVM heap limits as current RAM consumption.

For each large process, inspect its PPID chain, working directory, start time,
CPU/I/O activity, and `/proc/PID/cgroup`. Match these to live Codex, Claude,
pi.dev or other coding sessions and their test/build subprocesses. Inspect
process names and arguments without printing environment variables, secrets,
complete prompts, or arbitrary session transcripts.

When tmux is present, list pane PIDs, current commands and directories. Read
only enough pane status to distinguish working, waiting and idle sessions;
a historical “Working” message alone is insufficient. Codex's managed server
can execute tools for several CLI sessions, so tool children may belong to
the shared server rather than the visible CLI process.

Gradle, Kotlin, adb and emulator processes can detach and be reparented to
systemd. Use their cgroups, build logs/status, sockets and recent activity to
classify them as active, idle-but-retained, or apparently abandoned. PPID 1,
old start time, or low CPU alone is not evidence of abandonment. Use existing
logs or lightweight status queries; do not trigger a build to check activity.

Keep active agents, browsers, tests and emulators running. Stop or restart a
process only when session evidence establishes abandonment and the user's
cleanup scope covers it; prefer the tool's graceful shutdown command. Treat
ambiguous ownership as unresolved rather than guessing.

## Find disposable tmpfs artifacts

Start with a size-ranked inventory of `/tmp`. Check whether other large
scratch locations are tmpfs or disk-backed before attributing them to RAM.
Large agent downloads, extracted assets, virtual environments and isolated
build caches are useful candidates; don't assume every old directory is trash.

For each candidate, record its exact path, allocated size, owner, filesystem,
newest descendant-file modification time, and purpose. Directory mtime alone
misses writes to existing files. Historical examples such as comic extraction
trees or per-run build caches are hints, never permanent deletion globs.

Scan accessible processes for references in `/proc/PID/fd`, `cwd`, `exe`,
`maps`, and command arguments. Match complete paths or directory boundaries,
not loose substrings. Exclude the inspector's embedded source text from
argument matches. Include processes outside the current agent's own tree.
Report permission gaps; absence of accessible references is evidence, not
proof that a session will never reuse a path.

When swap attribution remains unclear, `fincore --json --bytes` can inspect
file residency without reading file contents. Nonresident tmpfs data helps
explain swap that process VmSwap totals miss; sparse holes also affect the
comparison. Do not read gigabytes of files just to measure them.

## Clean and verify

For authorized cleanup, remove only reviewed disposable paths with no live
references or recent changes. Recheck activity immediately before deletion.
Use an explicit path list; validate ownership and file type, reject symlink
roots, and verify device/inode identity if an earlier inventory is reused.
Do not cross nested mount points. Preserve active temporary directories.

Do not blanket-delete `/tmp`, clear useful page caches, run `swapoff`, kill
all Java/node processes, or change persistent VM settings as routine cleanup.
Those actions have different effects and require a specific diagnosis and
scope. If nothing is clearly disposable, report that finding.

Repeat memory, swap, zram, tmpfs usage and pressure measurements. Report exact
paths removed, allocated space deleted, changes in available RAM and swap,
and any processes stopped. Separate measured gains from concurrent workload
changes. Do not claim deleted bytes equal physical RAM reclaimed.

If recurrence warrants a recommendation, suggest disk-backed scratch storage
for large agent artifacts. Verify the destination's mount and free space;
change TMPDIR or persistent configuration only within the requested scope.

For kernel accounting details, consult the
[tmpfs documentation](https://docs.kernel.org/filesystems/tmpfs.html) and
[zram documentation](https://docs.kernel.org/admin-guide/blockdev/zram.html).
