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

## Removable backup pool (`zusb`)

`zusb` is a **4-disk raidz2 ZFS pool on 1.8 TB USB-SATA disks** (ASMT ASM235CM
bridges) used as the **offline backup storage device** — plugged in and loaded
**roughly once per quarter** to back up data, then exported and unplugged. It
lives on whichever f-host it is currently plugged into (f1 as of 2026-07-20).

It is **not** auto-imported or auto-mounted at boot and is **not** in any
host's `zfskeys_datasets` (removable disks must never block boot). It is loaded
manually with `/usr/local/bin/zusb-load` and exported with
`/usr/local/bin/zusb-unload`.

The encryption root is `zusb/data/enc`, rekeyed to the same raw-key-on-stick
scheme as the other f-host secrets: `keyformat=raw`,
`keylocation=file:///keys/zusb.key`. The 32-byte key file `/keys/zusb.key` is
placed on **all four** `F3S_KEYS` sticks, and the load/unload scripts are
deployed to **all four** f-hosts, so the disk stack can be re-plugged to any
f-host and loaded there with no per-host setup.

`zusb/data/enc` was migrated from t450, where it was unlocked via a
passphrase-protected `zroot/secret` keystore (`/zroot/secret/zroot.enc.key`);
that old passphrase key is now obsolete for `zusb`.

Scripts and deployment docs live in the conf repo at
`f3s/freebsd-hosts/zusb/` (`zusb-load`, `zusb-unload`, `README.md`). The raw
key itself is **not** in git — it is copied stick-to-stick like the other keys.

The backup workflow itself is driven by `/opt/snonux/bin/backup/backup` (which
travels on the pool under `zusb/data/opt`); its S3 sync leg needs the AWS CLI
installed on the hosting f-host — see [Backups & Local-Path](backups.md) →
"AWS CLI setup on a FreeBSD host". The S3 credentials also ride on the pool at
`/opt/snonux/secrets/aws.credentials` and are wired in via a
`/root/.aws/credentials` symlink, so no secret material lives on host disks.
