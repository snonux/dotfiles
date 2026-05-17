# Storage Troubleshooting

NFS issues, ZFS pool SUSPENDED recovery, and thermal problems on the
Beelink S12 Pro mini-PCs.

## NFS Troubleshooting

### All r-nodes show "access denied" when mounting NFS

**Most likely cause**: `vfs.nfsd.nfs_privport=1` on the CARP MASTER. This happens after f-host reboots if `nfs_reserved_port_only` is not set to `NO` in rc.conf. The nfsd rc script (`/etc/rc.d/nfsd`) explicitly sets the sysctl based on this variable, overriding `/etc/sysctl.conf`. Fix: `doas sysrc nfs_reserved_port_only=NO` on both f0 and f1.

### stunnel appears not running but port 2323 is bound

`carpcontrol.sh` starts stunnel on CARP MASTER transition, but doesn't write a PID file. So `service stunnel status` reports "not running" even though stunnel is actually serving connections. Check with `doas sockstat -l | grep 2323`. If there's a stale stunnel process, kill it and restart: `doas kill <pid> && doas service stunnel start`.

### Pods stuck in ContainerCreating/Unknown after NFS recovery

After NFS is restored on the server side, the `nfs-mount-monitor` systemd timer on each r-node will auto-remount within ~10 seconds and force-delete stuck pods. If immediate recovery is needed: `mount /data/nfs/k3svolumes` on each r-node, then delete the stuck pods manually.

**Note:** The monitor catches three failure modes: missing mountpoint, stat hang (reads unresponsive), and **silent write hang** (reads OK but writes block — the hardest case, e.g. stunnel-wrapped NFSv4 after a CARP failover). Watch the consecutive-failure counter via Prometheus (`nfs_mount_monitor_consecutive_failures`) — warning fires at ≥3, critical at ≥5. At 5 consecutive failures the node cordons itself and reboots.

### Checklist for NFS outage on CARP MASTER (f0 or f1)

```sh
# 1. Check which host is CARP MASTER
ssh paul@f0 'ifconfig re0 | grep carp'
ssh paul@f1 'ifconfig re0 | grep carp'

# 2. On the MASTER, verify:
doas sysctl vfs.nfsd.nfs_privport          # must be 0
doas service nfsd status                   # must be running
doas sockstat -l | grep 2323              # stunnel must be listening
ls /data/nfs/nfs.DO_NOT_REMOVE            # ZFS dataset must be mounted

# 3. Fix if needed:
doas sysrc nfs_reserved_port_only=NO      # persist the fix
doas sysctl vfs.nfsd.nfs_privport=0       # apply immediately
doas service nfsd restart
# For stunnel, kill stale process if needed, then:
doas service stunnel start
```

## ZFS pool SUSPENDED recovery

**Symptoms**: `doas zpool status zdata` shows `state: SUSPENDED`. All IO to the pool is
halted — ZFS suspends itself to prevent corruption when IO errors exceed the threshold.
Commands like `zpool clear`, `zpool scrub`, `zpool offline`, and even `ls /data/nfs/` hang
indefinitely because they wait for kernel IO that will never complete.

**Known cause (2026-05-15)**: Samsung 870 EVO 1TB on f0 (ada1) hit 107 read errors and
105M+ write errors during normal operation. Subsequent investigation pointed at
**thermal throttling** in the small Beelink S12 Pro enclosure — see the Thermal
section below.

**Recovery — hard power cycle only**:
- Do NOT attempt `doas shutdown -r now` — if ZFS is suspended, the graceful shutdown hangs
  at ZFS pool export and may stay stuck for 30–60+ minutes.
- Do NOT attempt `doas zpool clear zdata` — it hangs because ada1 is unresponsive.
- Do NOT attempt `doas ifconfig re0 vhid 1 state backup` or `doas carp backup` to fail
  over to f1 first — these ifconfig ioctls can also be blocked when the kernel has too
  many stuck IO threads. They may return exit=1 silently.
- **Hard power cycle** (pull power or hold the power button) resolves the issue in ~9 s
  (Rocky Linux VMs come up automatically, ZFS pool imports cleanly on next boot).

**Post-recovery**:
```sh
# 1. Verify pool health
doas zpool status zdata          # should show ONLINE, 0 errors

# 2. Check SMART for drive health
doas smartctl -a /dev/ada1 | grep -iE '(temperature|reallocated|pending|uncorrectable|error)'

# 3. Start a scrub to verify data integrity
doas zpool scrub zdata
doas zpool status zdata          # monitor; "scrub repaired 0 in ..." means data intact

# 4. Verify NFS is serving (stunnel listening on CARP VIP)
doas sockstat -l | grep 2323
```

**After cluster recovery**:
- Check for cordoned nodes: `kubectl get nodes` — if r0/r1/r2 show `SchedulingDisabled`,
  uncordon them (see `nfs-mount-monitor.md` escalation section).
- Reset fail counters on all r-nodes: `echo 0 > /var/lib/nfs-mount-monitor/fail-count`

## Thermal Troubleshooting

The 2026-05-16 f0 incident — and the 2026-05-15 ZFS SUSPENDED above — both trace
back to **thermal problems in the Beelink S12 Pro enclosure**, not to any
software-side cause. The mitigations and side-investigations (zrepl interval,
autotrim, encryption overhead) are not what fixed it; reseating the drive and
improving cooling did.

### Symptoms of thermal throttling on f-hosts

- SSD I/O slowness (writes dropping from MB/s to KB/s)
- ZFS txg sync times jumping from <100 ms to many seconds
- rsync / zrepl jobs going into D-state (waiting on ZFS I/O)
- SMART reporting elevated drive temperature

### How to check temperatures

- **coretemp (real per-core die temps)**: `kldload coretemp; sysctl dev.cpu | grep temperature`
  - Persist via `/boot/loader.conf` (`coretemp_load="YES"`)
- **hw.acpi.thermal.tz0**: often a constant lie (e.g. always 27.9 °C) — do NOT rely on it
- **SSD temperature**: `smartctl -a /dev/adaN` (requires `smartmontools`; may not be installed)
- **Disk I/O performance**: `gstat -bp -I 1s -d` (FreeBSD `gstat`, not Linux `iostat`)

### Beelink S12 Pro specifics

- Small enclosure with passive/minimal cooling — heat accumulates fast under sustained load
- N100 CPU: normal idle ~40–55 °C; warn >70 °C idle; critical >85 °C under load
- NVMe sits close to CPU — both heat each other in the small chassis
- Enclosure gets hot to the touch before temps fully register in software

### Cause and resolution (2026-05-16 f0)

The cascade was thermal-only:

1. Hot enclosure (NVMe physically very hot) → SSD/SATA thermal throttling
2. Throttled disk → ZFS txg syncs balloon from <100 ms to multi-second
3. rsync / zrepl block on ZFS → D-state, hung pods on r-nodes

**Root cause**: hot enclosure / inadequate cooling. **Resolution**: shut down,
reseat the drive, clean dust and improve airflow; the disk recovered immediately
and ZFS txg sync times returned to normal.

### Remediation steps

1. SSH in and check temps: `kldload coretemp && sysctl dev.cpu | grep temperature`
2. If >80 °C: stop heavy I/O workloads to prevent thermal-induced ZFS errors
3. Physical: shut down, reseat NVMe, clean dust from vents, improve airflow
4. Persist coretemp: ensure `/boot/loader.conf` has `coretemp_load="YES"`

### Temperature monitoring

```sh
# FreeBSD: load coretemp for CPU package temperature
doas kldload coretemp
sysctl -a | grep temperature                      # hw.acpi.thermal.*: and dev.cpu.*:
# Persist across reboots
echo 'coretemp_load="YES"' | doas tee -a /boot/loader.conf

# SSD temperature (install smartmontools if absent)
doas pkg install -y smartmontools
doas smartctl -a /dev/ada1 | grep -i temperature  # "194 Temperature_Celsius"
```
