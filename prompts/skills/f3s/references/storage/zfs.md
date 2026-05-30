# ZFS Pools & Encryption

Covers the `zdata` pool layout on f0/f1, encryption keys held on per-host
USB sticks, and how to roll a new encrypted dataset (data and bhyve).

## Physical Disks

- **f0**: 512GB M.2 (OS/zroot) + Samsung SSD 870 EVO 1TB (zdata)
- **f1**: 512GB M.2 (OS/zroot) + Crucial CT1000BX500SSD1 1TB (zdata)
- **f2**: No second drive (no zdata pool)
- **f3**: 512GB M.2 (OS/zroot); no zdata pool yet (planned)

## zdata Pool Setup

On f0 and f1, create the zdata pool on the second SSD:

```sh
# Pool setup (f0 and f1 only)
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
