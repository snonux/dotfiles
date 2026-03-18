# Storage

## Architecture Overview

Persistent storage for k3s is served via **NFS over stunnel** from the FreeBSD hosts, backed by **ZFS** (`zdata` pool) with **CARP** for high availability and **zrepl** for continuous replication.

Note: Original plan was HAST, replaced by **zrepl** (ZFS send/receive) — more reliable, avoids ZFS corruption during failover that HAST caused.

## Physical Disks

- **f0**: 512GB M.2 (OS/zroot) + Samsung SSD 870 EVO 1TB (zdata)
- **f1**: 512GB M.2 (OS/zroot) + Crucial CT1000BX500SSD1 1TB (zdata)
- **f2**: No second drive (no zdata pool)
- **f3**: 512GB M.2 (OS/zroot); no zdata pool yet (planned)

## ZFS: zdata Pool Setup

On f0 and f1, create the zdata pool on the second SSD:

```sh
# Pool setup (f0 and f1 only)
doas zpool create zdata ada1   # ada1 = second SSD
```

## ZFS Encryption Keys (USB Key Storage)

Encryption keys are stored on USB flash drives (UFS-formatted, mounted at `/keys`).
All four hosts (f0/f1/f2/f3) have USB keys at `/dev/da0` mounted at `/keys`, each holding
all 8 key files as cross-host backups.

```sh
# Format and mount USB key (on each node)
doas newfs /dev/da0
echo '/dev/da0 /keys ufs rw 0 2' | doas tee -a /etc/fstab
doas mkdir /keys
doas mount /keys

# Generate keys (on f0, then copy to f1, f2, f3)
doas openssl rand -out /keys/f0.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f1.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f2.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f3.lan.buetow.org:bhyve.key 32
doas openssl rand -out /keys/f0.lan.buetow.org:zdata.key 32
doas openssl rand -out /keys/f1.lan.buetow.org:zdata.key 32
doas openssl rand -out /keys/f2.lan.buetow.org:zdata.key 32
doas openssl rand -out /keys/f3.lan.buetow.org:zdata.key 32
doas chown root /keys/* && doas chmod 400 /keys/*
# Copy to f1, f2, f3 via tarball
```

## ZFS Encryption Setup

```sh
# On f0 - create encrypted zdata dataset
doas zfs create -o encryption=on -o keyformat=raw \
  -o keylocation=file:///keys/f0.lan.buetow.org:zdata.key zdata/enc

# Create the NFS data dataset (replicated to f1)
doas zfs create zdata/enc/nfsdata
doas zfs set mountpoint=/data/nfs zdata/enc/nfsdata
doas mkdir -p /data/nfs/k3svolumes

# Encrypt Bhyve VM dataset (zroot/bhyve)
# Stop VMs first, rename old, create new encrypted, zfs send snapshot, then destroy old
doas vm stop rocky
doas zfs rename zroot/bhyve zroot/bhyve_old
doas zfs set mountpoint=/mnt zroot/bhyve_old
doas zfs snapshot zroot/bhyve_old/rocky@hamburger
doas zfs create -o encryption=on -o keyformat=raw \
  -o keylocation=file:///keys/f0.lan.buetow.org:bhyve.key zroot/bhyve
doas zfs send zroot/bhyve_old/rocky@hamburger | doas zfs recv zroot/bhyve/rocky
# Copy vm-bhyve metadata: .config, .img, .templates, .iso
doas zfs destroy -R zroot/bhyve_old
```

### Auto-load encryption keys on boot

```sh
# On f0
doas sysrc zfskeys_enable=YES
doas sysrc zfskeys_datasets="zdata/enc zdata/enc/nfsdata zroot/bhyve"

# On f1
doas sysrc zfskeys_enable=YES
doas sysrc zfskeys_datasets="zdata/enc zroot/bhyve zdata/sink/f0/zdata/enc/nfsdata"

# On f3 (bhyve VMs only, no zdata pool yet)
doas sysrc zfskeys_enable=YES
doas sysrc zfskeys_datasets="zroot/bhyve"
doas zfs set keylocation=file:///keys/f0.lan.buetow.org:zdata.key \
  zdata/sink/f0/zdata/enc/nfsdata
```

## zrepl: Continuous ZFS Replication (f0 → f1)

Install on both f0 and f1:
```sh
doas pkg install -y zrepl
```

### f0 configuration (`/usr/local/etc/zrepl/zrepl.yml`)

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: f0_to_f1_nfsdata
    type: push
    connect:
      type: tcp
      address: "192.168.2.131:8888"   # f1 WireGuard IP
    filesystems:
      "zdata/enc/nfsdata": true
    send:
      encrypted: true
    snapshotting:
      type: periodic
      prefix: zrepl_
      interval: 1m                    # every minute
    pruning:
      keep_sender:
        - type: last_n
          count: 10
        - type: grid
          grid: 4x7d | 6x30d
          regex: "^zrepl_.*"
      keep_receiver:
        - type: last_n
          count: 10
        - type: grid
          grid: 4x7d | 6x30d
          regex: "^zrepl_.*"

  # Note: f0_to_f1_freebsd job removed — the FreeBSD VM was migrated to f3.
  # It is now replicated from f3 → f2 (see f3 zrepl config below).
```

### f3 configuration (push: freebsd VM → f2)

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: f3_to_f2_freebsd
    type: push
    connect:
      type: tcp
      address: "192.168.2.132:8888"   # f2 WireGuard IP
    filesystems:
      "zroot/bhyve/freebsd": true     # development FreeBSD VM
    send:
      encrypted: true
    snapshotting:
      type: periodic
      prefix: zrepl_
      interval: 10m
    pruning:
      keep_sender:
        - type: last_n
          count: 10
        - type: grid
          grid: 4x7d
          regex: "^zrepl_.*"
      keep_receiver:
        - type: last_n
          count: 10
        - type: grid
          grid: 4x7d
          regex: "^zrepl_.*"
```

### f2 configuration (sink for f3's freebsd VM)

f2 has no second drive so the sink lives in `zroot/sink`:

```sh
doas zfs create zroot/sink
```

`/usr/local/etc/zrepl/zrepl.yml`:

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: sink
    type: sink
    serve:
      type: tcp
      listen: "192.168.2.132:8888"    # f2 WireGuard IP
      clients:
        "192.168.2.133": "f3"
    recv:
      placeholder:
        encryption: inherit
    root_fs: "zroot/sink"
```

Replicated path: `zroot/bhyve/freebsd` → `zroot/sink/f3/zroot/bhyve/freebsd`

### f1 configuration (sink)

```sh
doas zfs create zdata/sink   # receive dataset
```

`/usr/local/etc/zrepl/zrepl.yml`:

```yaml
global:
  logging:
    - type: stdout
      level: info
      format: human

jobs:
  - name: sink
    type: sink
    serve:
      type: tcp
      listen: "192.168.2.131:8888"
      clients:
        "192.168.2.130": "f0"
    recv:
      placeholder:
        encryption: inherit
    root_fs: "zdata/sink"
```

### Enable and start

```sh
doas sysrc zrepl_enable=YES
doas service zrepl start
doas zrepl status   # monitor replication
```

Replicated paths: `zdata/enc/nfsdata` → `zdata/sink/f0/zdata/enc/nfsdata`

### Mount replica on f1 (read-only standby)

```sh
doas zfs load-key -L file:///keys/f0.lan.buetow.org:zdata.key \
  zdata/sink/f0/zdata/enc/nfsdata
doas mkdir -p /data/nfs
doas zfs set mountpoint=/data/nfs zdata/sink/f0/zdata/enc/nfsdata
doas zfs mount zdata/sink/f0/zdata/enc/nfsdata
doas zfs set readonly=on zdata/sink/f0/zdata/enc/nfsdata   # prevent replication breakage
```

### Failover design: intentionally read-only replica

The standby replica is read-only by design. Manual failover (not automatic) to prevent split-brain. To fix broken replication after accidental writes: `doas zfs rollback <snapshot>`.

### zrepl troubleshooting

```sh
# Signal manual replication
doas zrepl signal wakeup f0_to_f1_nfsdata

# Fix "no common snapshot" — destroy and re-replicate
doas zfs destroy -r zdata/sink/f0/zdata/enc/nfsdata

# Test network connectivity
nc -zv 192.168.2.131 8888

# Monitor progress
doas zrepl status --mode raw | grep BytesReplicated
```

## CARP: High-Availability VIP

CARP (Common Address Redundancy Protocol) provides **VIP 192.168.1.138** that floats between f0 (primary) and f1 (standby).

### /etc/rc.conf configuration

```sh
# On f0 (default advskew=0, wins elections)
ifconfig_re0_alias0="inet vhid 1 pass YOURPASSWORD alias 192.168.1.138/32"

# On f1 (advskew=100, loses elections to f0)
ifconfig_re0_alias0="inet vhid 1 advskew 100 pass YOURPASSWORD alias 192.168.1.138/32"
```

### Load CARP module

```sh
echo 'carp_load="YES"' | doas tee -a /boot/loader.conf
# or immediately: doas kldload carp
```

### /etc/hosts for CARP VIP

```
192.168.1.138 f3s-storage-ha f3s-storage-ha.lan f3s-storage-ha.lan.buetow.org
192.168.2.138 f3s-storage-ha.wg0 f3s-storage-ha.wg0.wan.buetow.org
```

### devd: CARP state change hook

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

### carpcontrol.sh — start/stop NFS+stunnel on failover

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

### CARP management script (`/usr/local/bin/carp`)

```sh
doas carp             # show current state
doas carp master      # force MASTER (e.g. reclaim after maintenance)
doas carp backup      # force BACKUP (trigger failover to f1)
doas carp auto-failback disable   # prevent auto-failback (for maintenance)
doas carp auto-failback enable    # re-enable auto-failback
```

### Auto-failback from f1 to f0

Script `/usr/local/bin/carp-auto-failback.sh` runs every minute via cron on f0. Checks: currently BACKUP? `/data/nfs` mounted? Marker file exists? Failback not blocked? If all conditions met, promotes f0 to MASTER.

```sh
echo "* * * * * /usr/local/bin/carp-auto-failback.sh" | doas crontab -
doas touch /data/nfs/nfs.DO_NOT_REMOVE   # marker file required for auto-failback
```

Logs to `/var/log/carp-auto-failback.log`.

## NFS Server Configuration (f0 and f1)

```sh
doas sysrc nfs_server_enable=YES
doas sysrc nfsv4_server_enable=YES
doas sysrc nfsuserd_enable=YES
doas sysrc nfsuserd_flags="-domain lan.buetow.org"
doas sysrc mountd_enable=YES
doas sysrc rpcbind_enable=YES

doas mkdir -p /data/nfs/k3svolumes
doas chmod 755 /data/nfs/k3svolumes
```

> **FreeBSD 15.0 note**: FreeBSD 15.0 changed the default for `vfs.nfsd.nfs_privport` from `0` to `1`, requiring NFS clients to connect from privileged ports (<1024). NFS over stunnel uses unprivileged ports, so this breaks all NFS mounts on the r-hosts. Fix on **each f-host**:
> ```sh
> # Apply immediately
> doas sysctl vfs.nfsd.nfs_privport=0
> # Persist across reboots
> echo "vfs.nfsd.nfs_privport=0" | doas tee -a /etc/sysctl.conf
> # Remount on each r-host
> mount -a
> ```

`/etc/exports` (stunnel clients appear as localhost):

```
V4: /data/nfs -sec=sys
/data/nfs -alldirs -maproot=root -network 127.0.0.1 -mask 255.255.255.255
```

Start services:

```sh
doas service rpcbind start
doas service mountd start
doas service nfsd start
doas service nfsuserd start
```

## stunnel: Encrypted NFS over TLS

stunnel binds to the CARP VIP (192.168.1.138), so only the CARP MASTER accepts connections. Uses mutual TLS with client certificate authentication.

### Create CA and certificates (on f0)

```sh
doas mkdir -p /usr/local/etc/stunnel/ca
cd /usr/local/etc/stunnel/ca
doas openssl genrsa -out ca-key.pem 4096
doas openssl req -new -x509 -days 3650 -key ca-key.pem -out ca-cert.pem \
  -subj '/C=US/ST=State/L=City/O=F3S Storage/CN=F3S Stunnel CA'

cd /usr/local/etc/stunnel
doas openssl genrsa -out server-key.pem 4096
doas openssl req -new -key server-key.pem -out server.csr \
  -subj '/C=US/ST=State/L=City/O=F3S Storage/CN=f3s-storage-ha.lan'
doas openssl x509 -req -days 3650 -in server.csr -CA ca/ca-cert.pem \
  -CAkey ca/ca-key.pem -CAcreateserial -out server-cert.pem

# Client certs for r0, r1, r2, earth
for client in r0 r1 r2 earth; do
  openssl genrsa -out ca/${client}-key.pem 4096
  openssl req -new -key ca/${client}-key.pem -out ca/${client}.csr \
    -subj "/C=US/ST=State/L=City/O=F3S Storage/CN=${client}.lan.buetow.org"
  openssl x509 -req -days 3650 -in ca/${client}.csr -CA ca/ca-cert.pem \
    -CAkey ca/ca-key.pem -CAcreateserial -out ca/${client}-cert.pem
  cat ca/${client}-cert.pem ca/${client}-key.pem > ca/${client}-stunnel.pem
done
```

### stunnel server config (`/usr/local/etc/stunnel/stunnel.conf`)

```
cert = /usr/local/etc/stunnel/server-cert.pem
key = /usr/local/etc/stunnel/server-key.pem
setuid = stunnel
setgid = stunnel

[nfs-tls]
accept = 192.168.1.138:2323
connect = 127.0.0.1:2049
CAfile = /usr/local/etc/stunnel/ca/ca-cert.pem
verify = 2
requireCert = yes
```

```sh
doas pkg install -y stunnel
doas sysrc stunnel_enable=YES
doas service stunnel start
# Copy certs to f1 via tarball, configure identically
```

## NFS Client Configuration (Rocky Linux r0, r1, r2)

```sh
dnf install -y stunnel nfs-utils

# Copy client cert and CA from f0
scp f0:/usr/local/etc/stunnel/ca/r0-stunnel.pem /etc/stunnel/
scp f0:/usr/local/etc/stunnel/ca/ca-cert.pem /etc/stunnel/
```

`/etc/stunnel/stunnel.conf` (r0 example):

```
cert = /etc/stunnel/r0-stunnel.pem
CAfile = /etc/stunnel/ca-cert.pem
client = yes
verify = 2

[nfs-ha]
accept = 127.0.0.1:2323
connect = 192.168.1.138:2323
```

```sh
systemctl enable --now stunnel
```

### NFSv4 user mapping

`/etc/idmapd.conf` on r0, r1, r2:

```
[General]
Domain = lan.buetow.org
```

Fix inotify limit:

```sh
echo 'fs.inotify.max_user_instances = 512' > /etc/sysctl.d/99-inotify.conf
sysctl -w fs.inotify.max_user_instances=512
systemctl enable --now nfs-client.target nfs-idmapd
```

### Mount NFS

```sh
mkdir -p /data/nfs/k3svolumes
mount -t nfs4 -o port=2323 127.0.0.1:/k3svolumes /data/nfs/k3svolumes
```

`/etc/fstab`:

```
127.0.0.1:/k3svolumes /data/nfs/k3svolumes nfs4 port=2323,_netdev,soft,timeo=10,retrans=2,intr 0 0
```

NFS path structure on k3s nodes: `/data/nfs/k3svolumes/<app>/`

## AWS S3 Glacier Deep Archive Backups

Encrypted incremental ZFS snapshots from `zdata` pool backed up daily to **AWS S3 Glacier Deep Archive** via cron. Scripts adapted from FreeBSD Home NAS setup. Also performs periodic zpool scrubbing.

## Storage Summary

| Layer | Technology | Role |
|-------|-----------|------|
| Block | M.2+2.5" SSD (f0/f1) | Physical storage |
| Filesystem | ZFS (`zdata/enc`) | Data integrity, AES-256-GCM encryption |
| Replication | `zrepl` | Continuous ZFS replication f0→f1 (1min NFS, 10min VM) |
| HA | CARP VIP 192.168.1.138 | Automatic failover for NFS/stunnel |
| Network | NFS over stunnel | Encrypted shared storage, mutual TLS auth |
| LAN access | FreeBSD relayd on CARP VIP | TCP forwarding to k3s :80/:443 |
| Backup | S3 Glacier Deep Archive | Off-site encrypted backup |
