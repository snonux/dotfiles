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
