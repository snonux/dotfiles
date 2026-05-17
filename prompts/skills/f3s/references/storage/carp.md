# CARP: High-Availability VIP

CARP (Common Address Redundancy Protocol) provides **VIP 192.168.1.138** that floats between f0 (primary) and f1 (standby). The VIP is what NFS clients and the FreeBSD `relayd` ingress connect to, so only the current MASTER serves traffic.

## /etc/rc.conf configuration

```sh
# On f0 (default advskew=0, wins elections)
ifconfig_re0_alias0="inet vhid 1 pass YOURPASSWORD alias 192.168.1.138/32"

# On f1 (advskew=100, loses elections to f0)
ifconfig_re0_alias0="inet vhid 1 advskew 100 pass YOURPASSWORD alias 192.168.1.138/32"
```

## Load CARP module

```sh
echo 'carp_load="YES"' | doas tee -a /boot/loader.conf
# or immediately: doas kldload carp
```

## /etc/hosts for CARP VIP

```
192.168.1.138 f3s-storage-ha f3s-storage-ha.lan f3s-storage-ha.lan.buetow.org
192.168.2.138 f3s-storage-ha.wg0 f3s-storage-ha.wg0.wan.buetow.org
```

## devd: CARP state change hook

Add to `/etc/devd.conf` on f0 and f1:

```
notify 0 {
    match "system"    "CARP";
    match "subsystem" "[0-9]+@[0-9a-z.]+";
    match "type"      "(MASTER|BACKUP)";
    action "/usr/local/bin/carpcontrol.sh $subsystem $type";
};
```

```sh
doas service devd restart
```

## carpcontrol.sh — start/stop NFS+stunnel on failover

```sh
#!/bin/sh
HOSTNAME=`hostname`

if [ ! -f /data/nfs/nfs.DO_NOT_REMOVE ]; then
    logger '/data/nfs not mounted, mounting it now!'
    if [ "$HOSTNAME" = 'f0.lan.buetow.org' ]; then
        zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key zdata/enc/nfsdata
        zfs set mountpoint=/data/nfs zdata/enc/nfsdata
    else
        zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key zdata/sink/f0/zdata/enc/nfsdata
        zfs set mountpoint=/data/nfs zdata/sink/f0/zdata/enc/nfsdata
        zfs mount zdata/sink/f0/zdata/enc/nfsdata
        zfs set readonly=on zdata/sink/f0/zdata/enc/nfsdata
    fi
    service nfsd stop 2>&1
    service mountd stop 2>&1
fi

case "$2" in
    MASTER)
        logger "CARP state changed to MASTER, starting services"
        service rpcbind start >/dev/null 2>&1
        service mountd start >/dev/null 2>&1
        service nfsd start >/dev/null 2>&1
        service nfsuserd start >/dev/null 2>&1
        service stunnel restart >/dev/null 2>&1
        ;;
    BACKUP)
        logger "CARP state changed to BACKUP, stopping services"
        service stunnel stop >/dev/null 2>&1
        service nfsd stop >/dev/null 2>&1
        service mountd stop >/dev/null 2>&1
        service nfsuserd stop >/dev/null 2>&1
        ;;
esac
```

Install: `doas chmod +x /usr/local/bin/carpcontrol.sh` (copy to f1 too)

## CARP management script (`/usr/local/bin/carp`)

```sh
doas carp             # show current state
doas carp master      # force MASTER (e.g. reclaim after maintenance)
doas carp backup      # force BACKUP (trigger failover to f1)
doas carp auto-failback disable   # prevent auto-failback (for maintenance)
doas carp auto-failback enable    # re-enable auto-failback
```

## CARP failover limitation when ZFS is suspended

If f0's ZFS pool is SUSPENDED but f0's OS is still running, f0 remains CARP MASTER
(it keeps sending CARP advertisements). Attempts to manually demote f0 via:

```sh
doas carp backup                            # may return exit=0 but has no effect
doas ifconfig re0 vhid 1 state backup       # may return exit=1 silently
doas ifconfig re0 vhid 1 advskew 254        # may return exit=1 silently
```

…can all silently fail because the kernel has too many stuck IO threads blocking
the ifconfig ioctl path. The CARP VIP will **not** float to f1 in this case.
**Only a hard power cycle of f0 reliably triggers CARP failover.** See
[troubleshooting.md](troubleshooting.md) for the full SUSPENDED-pool recovery runbook.

## Auto-failback from f1 to f0

Script `/usr/local/bin/carp-auto-failback.sh` runs every minute via cron on f0. Checks: currently BACKUP? `/data/nfs` mounted? Marker file exists? Failback not blocked? If all conditions met, promotes f0 to MASTER.

```sh
echo "* * * * * /usr/local/bin/carp-auto-failback.sh" | doas crontab -
doas touch /data/nfs/nfs.DO_NOT_REMOVE   # marker file required for auto-failback
```

Logs to `/var/log/carp-auto-failback.log`.
