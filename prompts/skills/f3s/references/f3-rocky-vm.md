# f3 Rocky VM

f3 hosts a plain Rocky Linux 9 bhyve VM named `rocky`. This VM is not part of the k3s cluster and should stay vanilla unless a later task explicitly assigns a role.

## Current State

| Field | Value |
|-------|-------|
| FreeBSD host | `f3.lan.buetow.org` |
| vm-bhyve name | `rocky` |
| Guest hostname | `rocky` |
| LAN IP | `192.168.1.123/24` |
| Gateway | `192.168.1.1` |
| DNS | `192.168.1.127`, `192.168.1.128`, fallback `192.168.1.1` |
| OS | Rocky Linux 9.7 (Blue Onyx), x86_64 |
| SSH | `root@192.168.1.123` |
| VNC | `f3.lan.buetow.org:5900` while graphics are enabled |

## vm-bhyve Policy on f3

`rocky` is the default VM on f3:

```sh
doas sysrc vm_list="rocky"
doas sysrc vm_delay="5"
```

The older FreeBSD development VM on f3 should remain stopped by default:

```sh
doas vm list
# freebsd  ...  AUTO No   Stopped
# rocky    ...  AUTO Yes  Running
```

Do not add `freebsd` back to `vm_list` unless the desired boot policy changes.

## VM Config

Config path on f3:

```text
/zroot/bhyve/rocky/rocky.conf
```

Expected config shape:

```conf
loader="uefi"
uefi_vars="yes"
guest="linux"
cpu=4
memory=14G
network0_type="virtio-net"
network0_switch="public"
disk0_type="nvme"
disk0_name="disk0.img"
graphics="yes"
graphics_vga=io
graphics_wait="no"
uuid="<unique>"
network0_mac="<unique>"
```

Disk:

```text
/zroot/bhyve/rocky/disk0.img
200G sparse file  (was 100G, expanded 2026-06-09)
NVMe emulation
```

Guest disk layout (LVM on GPT):

| Device | Size | Type | Mount |
|--------|------|------|-------|
| /dev/nvme0n1p1 | 600M | EFI System | /boot/efi |
| /dev/nvme0n1p2 | 1G | ext4 | /boot |
| /dev/nvme0n1p3 | ~198G | Linux LVM | PV for rlm_rocky |
| └─ rlm_rocky-root | 61.5G | XFS | / |
| └─ rlm_rocky-swap | 6.9G | swap | [SWAP] |
| └─ rlm_rocky-home | 130G | XFS | /home |

## Verification

From a machine on the LAN:

```sh
ssh root@192.168.1.123 'hostname; cat /etc/rocky-release; ip -4 -brief addr show enp0s5; systemctl is-active sshd'
```

Expected:

```text
rocky
Rocky Linux release 9.7 (Blue Onyx)
enp0s5 UP 192.168.1.123/24
active
```

From f3:

```sh
doas vm list
doas vm info rocky
```

## Notes

- Keep this VM plain unless a later task explicitly installs packages or assigns a service role.
- Root SSH is intentionally enabled for LAN-only administration.
- The guest was installed from the Rocky Linux 9.7 minimal ISO using an unattended kickstart. See `bootstrap-rocky-bhyve.md` for the bootstrap procedure.
