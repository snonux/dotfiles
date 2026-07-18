# USB Key Mounting for ZFS Encryption

The f-hosts keep raw ZFS encryption keys on per-host UFS USB sticks mounted at
`/keys`. All four sticks are labeled `F3S_KEYS` and hold all 8 key files as
cross-host backups.

Do **not** mount `/keys` from `/etc/fstab`. A missing or corrupt key stick must
not block the FreeBSD base OS from booting.

## Managed Files

Source files live in the conf repo:

```text
f3s/freebsd-hosts/keys/
  f3s-mount-keys
  f3s-load-zfs-keys
  f3skeys.rc
```

Installed paths on each f-host:

```text
/usr/local/sbin/f3s-mount-keys
/usr/local/sbin/f3s-load-zfs-keys
/etc/rc.d/f3skeys
```

`f3skeys` runs before FreeBSD's built-in `zfskeys` service. If the USB stick is
missing or `fsck_ufs -p` fails, the helper logs the problem and exits
successfully so boot continues. Encrypted datasets stay locked until the stick
is repaired and `/usr/local/sbin/f3s-load-zfs-keys` is run manually.

## Setup

Format a new key stick:

```sh
doas newfs -L F3S_KEYS /dev/da0
doas mkdir -p /keys
doas mount -t ufs -o ro /dev/ufs/F3S_KEYS /keys
```

Label an existing stick without rebuilding it:

```sh
doas umount /keys
doas tunefs -L F3S_KEYS /dev/da0
```

Keep the old `/etc/fstab` line commented on all f-hosts:

```fstab
# /dev/da0 /keys ufs rw 0 2
```

Enable boot loading:

```sh
doas sysrc f3skeys_enable=YES
doas sysrc zfskeys_enable=YES
```

Current `zfskeys_datasets` values:

```sh
# f0
doas sysrc zfskeys_datasets="zdata/enc zdata/enc/nfsdata zroot/bhyve zroot/garage"

# f1
doas sysrc zfskeys_datasets="zdata/enc zroot/bhyve zroot/garage zdata/sink/f0/zdata/enc/nfsdata"

# f2
doas sysrc zfskeys_datasets="zdata/enc zroot/bhyve zroot/garage zroot/sink/f3/zroot/bhyve/freebsd"

# f3
doas sysrc zfskeys_datasets="zroot/bhyve"
```

Replicated sinks with raw encryption need explicit file keylocations:

```sh
# f1
doas zfs set keylocation=file:///keys/f0.lan.buetow.org:zdata.key \
  zdata/sink/f0/zdata/enc/nfsdata

# f2
doas zfs set keylocation=file:///keys/f3.lan.buetow.org:bhyve.key \
  zroot/sink/f3/zroot/bhyve/freebsd
```

Manual recovery after boot:

```sh
doas /usr/local/sbin/f3s-mount-keys --strict
doas /usr/local/sbin/f3s-load-zfs-keys
```

## Verification

```sh
mount | grep ' /keys '
sysrc -n f3skeys_enable
sysrc -n zfskeys_enable
sysrc -n zfskeys_datasets
doas /usr/local/sbin/f3s-load-zfs-keys
zfs list -H -o name,encryption,keylocation,keystatus,mounted |
  awk '$2 != "off" { print }'
```

Full reboot validation was run on f0, f1, f2, and f3 on 2026-05-30 after this
change.

Note: `zroot/sink/f3/zroot/bhyve/freebsd` on f2 has `mountpoint=none`; the
reboot check expects its key to be `available`, but it is not mounted because it
has no filesystem mountpoint.
