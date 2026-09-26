# ZFS Pools & Encryption

Covers the `zdata` pool layout on f0/f1/f2, pool feature flags, encryption
keys held on per-host USB sticks, and how to roll a new encrypted dataset
(data and bhyve).

## Physical Disks

- **f0**: 512GB M.2 (OS/zroot) + SanDisk Ultra 3D 4TB (zdata, `ada1`)
- **f1**: 512GB M.2 (OS/zroot) + WD Blue SA510 4TB (zdata, `ada1`)
- **f2**: 512GB M.2 (OS/zroot) + Samsung SSD 870 EVO 1TB (zdata, `ada1`;
  holds `zdata/enc/earth-backup`)
- **f3**: 512GB M.2 (OS/zroot); no zdata pool yet (planned)

## zdata Pool Setup

On f0, f1 and f2, create the zdata pool on the second SSD:

```sh
# Pool setup (f0, f1 and f2)
doas zpool create zdata ada1   # ada1 = second SSD
```

## Encryption Keys (USB Key Storage)

Encryption keys are stored on USB flash drives (UFS-formatted, mounted at
`/keys`). All four hosts (f0/f1/f2/f3) have USB keys with UFS label
`F3S_KEYS`, mounted at `/keys`, each holding all 8 key files as cross-host
backups.

Do **not** mount `/keys` from `/etc/fstab`. A missing or corrupt key stick must
not block the FreeBSD base OS from booting. See [USB Key Mounting](usb-keys.md)
for the `f3skeys` boot helper, install paths, current `zfskeys_datasets`, and
reboot validation.

```sh
# Format and mount USB key (on each node)
doas newfs -L F3S_KEYS /dev/da0
doas mkdir /keys
doas mount -t ufs -o ro /dev/ufs/F3S_KEYS /keys

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

If an existing stick has no label, unmount it and label it without rebuilding
the filesystem:

```sh
doas umount /keys
doas tunefs -L F3S_KEYS /dev/da0
```

## Encryption Setup

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

Boot-time key loading is managed by `f3skeys` plus FreeBSD's `zfskeys`. Keep
the per-host dataset list in [USB Key Mounting](usb-keys.md) up to date when
adding encrypted ZFS roots.

## Pool feature flags (`zpool upgrade`)

All f-hosts run OpenZFS 2.4.2 (kmod and userland). Enabling a feature
cannot be undone. An *enabled* feature alone does not block older importers;
once a new feature becomes *active* (e.g. `block_cloning_endian` on the
first BRT ZAP), pre-2.4 software can no longer import the pool, so treat it
as 2.4+ only. Decision
(2026-09-26): no older system (rescue media, FreeBSD 14, t450, a bhyve
restore-drill guest, see the f3s skill's `backup-restore-test.md`) needs to
import `zdata`, so no `compatibility=` pin (it stays `off`).

- **zroot**: only f3 has all features enabled. On f0/f1/f2 zroot still has
  the same 8 features disabled (checked 2026-09-26); left alone because it
  is the boot pool. The loaders on the EFI partition of f0/f1/f2
  (`/boot/efi/efi/boot/bootx64.efi`, `/boot/efi/efi/freebsd/loader.efi`)
  are still the Dec 2024 builds (660480 bytes), not the 15.1
  `/boot/loader.efi` (Jun 2026). Before any zroot upgrade, copy
  `/boot/loader.efi` over both EFI-partition paths. The loader only has to
  understand features that are *active* and not read-only compatible, so
  enabled-but-unused features do not break boot. f3 boots with all features
  enabled on its Mar 2026 EFI loader (665088 bytes, also older than
  `/boot/loader.efi`); that is no evidence for the Dec 2024 loaders on
  f0/f1/f2.
- **zdata** f2, f1, f0 (in that order, 2026-09-26, online, no reboot):
  `zpool upgrade zdata` enabled `redaction_list_spill`, `raidz_expansion`,
  `fast_dedup`, `longname`, `large_microzap`, `block_cloning_endian`,
  `physical_rewrite`. Each pool had a clean scrub the same day; afterwards
  `zpool status -x` healthy, write probe on `/data`, zrepl f0 -> f1
  (`zdata/sink/f0`) kept replicating, NFS writes from r0-r2 OK.
- **`dynamic_gang_header`** stays disabled on purpose: `zpool upgrade` never
  enables it; it must be set manually or via a compatibility file. It is not
  read-only compatible and only helps extremely fragmented pools. Enable only
  deliberately with
  `zpool set feature@dynamic_gang_header=enabled`.
- **zusb** (see [usb-keys.md](usb-keys.md)): not upgraded; it is exported
  most of the time, so its feature state is unrecorded (check at the next
  `zusb-load` with `zpool get all zusb | grep feature@`). Upgrade it only
  while imported, after a clean scrub, and after confirming no pre-2.4
  system must import it (`zusb/data/enc` was migrated from
  t450; see usb-keys.md).

Check with `zpool get all <pool> | grep feature@ | grep disabled` (no `doas`
needed).
