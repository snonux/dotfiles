# NFS over stunnel

NFSv4 served from f0/f1 to the Rocky Linux k3s nodes (r0/r1/r2) over a
TLS tunnel that terminates on the CARP VIP. NFS itself stays on localhost;
stunnel handles transport encryption with mutual TLS.

## NFS Server Configuration (f0 and f1)

```sh
doas sysrc nfs_server_enable=YES
doas sysrc nfsv4_server_enable=YES
doas sysrc nfsuserd_enable=YES
doas sysrc nfsuserd_flags="-domain lan.buetow.org"
doas sysrc mountd_enable=YES
doas sysrc rpcbind_enable=YES
doas sysrc nfs_reserved_port_only=NO   # Required for NFS over stunnel (unprivileged ports)

doas mkdir -p /data/nfs/k3svolumes
doas chmod 755 /data/nfs/k3svolumes
```

> **FreeBSD 15.0 note**: FreeBSD 15.0 sets `nfs_reserved_port_only=YES` by default in `/etc/defaults/rc.conf`. The nfsd rc script (`/etc/rc.d/nfsd`) checks this variable and explicitly runs `sysctl vfs.nfsd.nfs_privport=1` at startup, overriding any value set in `/etc/sysctl.conf` or `/boot/loader.conf`. This blocks NFS clients connecting via stunnel (unprivileged ports). Fix on **each f-host**:
> ```sh
> # The ONLY correct fix — setting sysctl.conf does NOT work
> doas sysrc nfs_reserved_port_only=NO
> # Apply immediately without reboot
> doas sysctl vfs.nfsd.nfs_privport=0
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
127.0.0.1:/k3svolumes /data/nfs/k3svolumes nfs4 port=2323,_netdev,hard,timeo=600,retrans=3 0 0
```

NFS path structure on k3s nodes: `/data/nfs/k3svolumes/<app>/`

The `nfs-mount-monitor` watchdog on each r-node detects and repairs stale or
hung mounts automatically — see [nfs-mount-monitor.md](nfs-mount-monitor.md).

## NFS Client Configuration (earth, roaming laptop)

`earth` mounts two exports (`/earthdata`, `/k3svolumes`) the same way as the
r-nodes — local stunnel client on `127.0.0.1:2323` → CARP VIP `192.168.1.138:2323`.
Certs live in `/etc/stunnel/` (`earth-stunnel.pem`, `ca-cert.pem`). The mounts are
`noauto` and mounted on demand.

**Mount options differ from the r-nodes on purpose.** The r-nodes are on a fast,
stable LAN and use `hard,timeo=600`. `earth` roams on WiFi, so it uses `soft` so it
fails instead of hanging forever when off-network. The working `/etc/fstab` lines:

```
127.0.0.1:/earthdata   /data/nfs/earthdata   nfs4 port=2323,_netdev,soft,timeo=150,retrans=3,nofail,noauto 0 0
127.0.0.1:/k3svolumes  /data/nfs/k3svolumes  nfs4 port=2323,_netdev,soft,timeo=150,retrans=3,nofail,noauto 0 0
```

> **Critical: do NOT use `timeo=10` on earth.** `timeo` is in **deciseconds**, so
> `timeo=10` = **1.0s per RPC**. A large write is split into many `wsize` (128KB)
> RPCs plus a final `COMMIT`; with `soft,timeo=10,retrans=2`, any single RPC or the
> COMMIT that can't be acked within ~1s over jittery WiFi makes the soft mount abort
> mid-transfer with EIO. That both **corrupts the partial file** and leaves a wedged
> NFS session that retransmits constantly, saturating 2.4GHz WiFi airtime (slows ALL
> WiFi traffic, e.g. unrelated scp to/from earth). `timeo=150` (15s) gives each RPC
> and the COMMIT enough slack to ride out WiFi jitter while still failing eventually
> if truly disconnected. Drop the deprecated `intr` option (no-op on modern Linux).

**Superblock caching gotcha:** Linux NFS shares one superblock per `server:export`,
so remounting with new options is ignored while any process still references the old
mount (e.g. a shell with its cwd inside it). Either release all references first, or
remount with `-o nosharecache` to force a fresh superblock with the new options.

**The real fix is the mount option, not the transfer tool.** With `timeo=150` the
mount never wedges, so transfers just complete and plain `cp`/`mv` are perfectly
safe — they check return codes and report errors normally. The one time we saw a
half-finalized destination file, it was *not* a `cp`/`mv` flaw: the in-flight `mv`
was killed mid-finalize by a forced f0 reboot + stunnel restart that we only did
*because* the mount had wedged (the `timeo=10` bug). Fix the hang and that whole
chain disappears. `rsync` (temp-file-then-rename, `--remove-source-files` only after
a verified copy) is worth using as **interruption insurance** on a flaky WiFi link —
it can't leave a bad file under the real name if the link dies mid-transfer — but it
is not a substitute for the `timeo` fix and `cp`/`mv` do not "cause corruption."
