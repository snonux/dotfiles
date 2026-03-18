# Rocky Linux Bhyve VMs

## Why Rocky Linux 9

- Long-term support: EOL 2032 — no major upgrades needed
- RHEL-family compatible (consistent with work and Fedora laptop)
- Supports Kubernetes (k3s), eBPF, systemd

## Bhyve Setup on FreeBSD Hosts

Tool: **vm-bhyve** (not built into FreeBSD, installed via pkg).

### Install and initialise (run on each of f0, f1, f2)
```sh
doas pkg install vm-bhyve bhyve-firmware
doas sysrc vm_enable=YES
doas sysrc vm_dir=zfs:zroot/bhyve
doas zfs create zroot/bhyve
doas vm init
doas vm switch create public
doas vm switch add public re0    # re0 = Realtek GbE interface
doas ln -s /zroot/bhyve/ /bhyve  # convenience symlink
```

### Verify CPU virtualisation support
```sh
dmesg | grep 'Features2=.*POPCNT'  # must show POPCNT
```

## VM Configuration

### Download ISO and create VM
```sh
doas vm iso https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.5-x86_64-minimal.iso
doas vm create rocky
doas truncate -s 100G /zroot/bhyve/rocky/disk0.img  # expand before install
```

### VM config (`/zroot/bhyve/rocky/rocky.conf`)
```
guest="linux"
loader="uefi"
uefi_vars="yes"
cpu=4
memory=14G
network0_type="virtio-net"
network0_switch="public"
disk0_type="nvme"           # NVMe emulation (see below)
disk0_name="disk0.img"
graphics="yes"
graphics_vga=io
uuid="<unique per host>"
network0_mac="<unique per host>"
```

The `uuid` and `network0_mac` differ for each of the three VMs.

### Install from ISO (interactive via VNC)
```sh
doas vm install rocky Rocky-9.5-x86_64-minimal.iso
# VNC address: vnc://f0:5900, vnc://f1:5900, vnc://f2:5900
```

Use GNOME VNC client from `earth` (Fedora laptop) to complete the graphical installer.

## After Install

### Auto-start VM on host reboot
```sh
cat <<END | doas tee -a /etc/rc.conf
vm_list="rocky"
vm_delay="5"
END
```

### VM IP and hostname (Rocky Linux side)
```sh
nmcli connection modify enp0s5 ipv4.address 192.168.1.120/24
nmcli connection modify enp0s5 ipv4.gateway 192.168.1.1
nmcli connection modify enp0s5 ipv4.DNS 192.168.1.1
nmcli connection modify enp0s5 ipv4.method manual
nmcli connection down enp0s5 && nmcli connection up enp0s5
hostnamectl set-hostname r0.lan.buetow.org
```

VM IPs:

| VM | LAN IP | Runs on |
|----|--------|---------|
| r0 | 192.168.1.120 | f0 |
| r1 | 192.168.1.121 | f1 |
| r2 | 192.168.1.122 | f2 |

VM names inside bhyve are all called `rocky` (one per host).

### SSH access
```sh
# Enable root login (VMs are not internet-reachable)
# Add to /etc/ssh/sshd_config: PermitRootLogin yes

# Copy SSH keys from laptop
for i in 0 1 2; do ssh-copy-id root@r$i.lan.buetow.org; done

# Disable password auth after keys are in place
# Set PasswordAuthentication no in /etc/ssh/sshd_config
```

### Update Rocky Linux
```sh
dnf update -y && reboot
```

## Critical: NVMe Disk Emulation for etcd

**Problem**: Default `virtio-blk` disk gives ~258 kB/s sync write speed, causing etcd leader elections and "apply request took too long" warnings.

**Symptom in k3s logs**:
```
{"level":"warn","msg":"slow fdatasync","took":"1.328469363s","expected-duration":"1s"}
```

**Solution**: Switch to NVMe emulation (~100x faster: 24.8 MB/s vs 258 kB/s).

### Step 1: Prepare guest OS (while still on virtio-blk)
```sh
# Add NVMe drivers to initramfs
cat > /etc/dracut.conf.d/nvme.conf << EOF
add_drivers+=" nvme nvme_core "
hostonly=no
EOF

# Allow LVM to scan all devices (device path changes from /dev/vda to /dev/nvme0n1)
sed -i 's/# use_devicesfile = 1/use_devicesfile = 0/' /etc/lvm/lvm.conf

dracut -f
shutdown -h now
```

### Step 2: Update VM config on FreeBSD host
```sh
doas vm stop rocky
# Edit rocky.conf: change disk0_type="virtio-blk" to disk0_type="nvme"
doas vm configure rocky
doas vm start rocky
```

### Caveats
- Do NOT add `disk0_opts="nocache,direct"` with NVMe — makes performance worse
- NVMe drivers must be in initramfs before switching
- LVM `use_devicesfile` must be 0 (disabled) — device path changes

## VM Management Commands

```sh
doas vm list                          # list all VMs and state
doas vm start rocky                   # start VM
doas vm stop rocky                    # graceful ACPI stop (can be slow)
doas vm reset rocky                   # force reset
doas sockstat -4 | grep 5900          # check VNC port
```

> **`vm stop` is ACPI-only** — it sends a shutdown signal but does not wait. If the VM does not shut down within a reasonable time, force-kill the bhyve process:
> ```sh
> doas vm list         # note the PID in parentheses, e.g. Running (2086)
> doas kill -9 2086
> ```
> **Warning**: Force-killing bhyve with `kill -9` mid-write can corrupt the k3s etcd WAL on the Rocky VM, causing a crash loop on next start. Only use as a last resort, and check etcd health after. See k3s-setup.md for the recovery procedure.
