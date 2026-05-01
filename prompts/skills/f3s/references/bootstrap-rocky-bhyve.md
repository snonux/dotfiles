# Bootstrap Rocky bhyve VM

This runbook creates a plain Rocky Linux 9 VM under vm-bhyve on an f3s FreeBSD host. Use it when adding a vanilla Rocky guest, especially on f3 where guests are standalone and not part of k3s.

## Preconditions

On the FreeBSD host:

```sh
doas pkg install vm-bhyve bhyve-firmware
doas sysrc vm_enable=YES
doas sysrc vm_dir=zfs:zroot/bhyve
doas zfs create zroot/bhyve
doas vm init
doas vm switch create public
doas vm switch add public re0
```

Check existing VM names and autostart policy before changing anything:

```sh
doas vm list
doas sysrc -n vm_list
```

Check candidate IPs from f3 and in the config/docs:

```sh
for ip in 192.168.1.123 192.168.1.124; do
  ping -c 2 -t 2 "$ip" >/dev/null 2>&1 && echo "$ip alive" || echo "$ip no-reply"
done
arp -an | egrep '192\.168\.1\.(123|124)' || true
egrep -R '192\.168\.1\.(123|124)' /etc /usr/local/etc /zroot/bhyve/.config 2>/dev/null || true
```

Also check the conf repo and f3s skill docs before reserving an address.

## Build an Unattended ISO

Work from a Linux workstation with `curl`, `bsdtar`, `genisoimage`, `mtools`, and `openssl`.

Download and verify the current Rocky Linux 9 minimal ISO:

```sh
mkdir -p /tmp/rocky-bhyve-build
cd /tmp/rocky-bhyve-build

curl -L --fail -O https://dl.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9-latest-x86_64-minimal.iso
curl -L --fail -O https://dl.rockylinux.org/pub/rocky/9/isos/x86_64/CHECKSUM
sha256sum Rocky-9-latest-x86_64-minimal.iso
cat CHECKSUM
```

Extract the ISO:

```sh
mkdir iso-root
bsdtar -C iso-root -xf Rocky-9-latest-x86_64-minimal.iso
chmod -R u+w iso-root/EFI/BOOT iso-root/isolinux iso-root/images
```

Create `ks.cfg`. Adjust `VM_NAME`, `IPADDR`, DNS, gateway, timezone, and SSH key as needed.

```sh
VM_NAME=rocky
IPADDR=192.168.1.123
ROOT_PASSWORD_FILE=/tmp/rocky-bhyve-build/root-password.txt
openssl rand -base64 18 | tr -d '/+=' | cut -c1-18 > "$ROOT_PASSWORD_FILE"
chmod 600 "$ROOT_PASSWORD_FILE"
ROOT_HASH=$(openssl passwd -6 "$(cat "$ROOT_PASSWORD_FILE")")
PUBKEY=$(sed -n '1p' ~/.ssh/id_rsa.pub)

cat > iso-root/ks.cfg <<EOF
text
reboot --eject
firstboot --disable
lang en_US.UTF-8
keyboard us
timezone Europe/Sofia --utc
network --device=link --bootproto=static --ip=$IPADDR --netmask=255.255.255.0 --gateway=192.168.1.1 --nameserver=192.168.1.127,192.168.1.128,192.168.1.1 --hostname=$VM_NAME --activate
rootpw --iscrypted $ROOT_HASH
sshkey --username=root "$PUBKEY"
firewall --enabled --ssh
selinux --enforcing
services --enabled=sshd,chronyd
zerombr
clearpart --all --initlabel
autopart --type=lvm

%packages
@^minimal-environment
%end

%post --log=/root/ks-post.log
mkdir -p /root/.ssh
chmod 700 /root/.ssh
if [ -f /root/.ssh/authorized_keys ]; then
    chmod 600 /root/.ssh/authorized_keys
fi
sed -ri 's/^#?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -ri 's/^#?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
grep -q '^PermitRootLogin ' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
grep -q '^PasswordAuthentication ' /etc/ssh/sshd_config || echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
grep -q '^UseDNS ' /etc/ssh/sshd_config || echo 'UseDNS no' >> /etc/ssh/sshd_config
%end
EOF
```

Patch both visible GRUB config and the embedded EFI boot image. The embedded `images/efiboot.img` has its own `EFI/BOOT/grub.cfg`; if it is not patched, UEFI bhyve will boot the normal interactive installer.

```sh
cp iso-root/EFI/BOOT/grub.cfg grub.cfg.orig
sed -i \
  -e 's/set default="1"/set default="0"/' \
  -e 's/set timeout=60/set timeout=5/' \
  -e '0,/inst.stage2=hd:LABEL=Rocky-9-7-x86_64-dvd quiet/s//inst.stage2=hd:LABEL=Rocky-9-7-x86_64-dvd inst.ks=cdrom:\/ks.cfg inst.text quiet/' \
  iso-root/EFI/BOOT/grub.cfg

mcopy -o -i iso-root/images/efiboot.img iso-root/EFI/BOOT/grub.cfg ::/EFI/BOOT/grub.cfg
mtype -i iso-root/images/efiboot.img ::/EFI/BOOT/grub.cfg | grep 'inst.ks'
```

Patch BIOS isolinux too, even if the f3s bhyve guests normally use UEFI:

```sh
cp iso-root/isolinux/isolinux.cfg isolinux.cfg.orig
sed -i \
  -e 's/^timeout .*/timeout 50/' \
  -e '/label linux/,/label check/ s/append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-9-7-x86_64-dvd quiet/append initrd=initrd.img inst.stage2=hd:LABEL=Rocky-9-7-x86_64-dvd inst.ks=cdrom:\/ks.cfg inst.text quiet/' \
  -e '/label linux/,/label check/ s/^  menu label .*/  menu label ^Install Rocky Linux Minimal unattended/' \
  -e '/label check/,/label fips/ s/^  menu default//' \
  iso-root/isolinux/isolinux.cfg

awk 'BEGIN{inlinux=0; added=0}
     /^label linux$/{inlinux=1; added=0; print; next}
     inlinux && /^  menu label / && !added {print "  menu default"; added=1; print; next}
     /^label check$/{inlinux=0}
     {print}' iso-root/isolinux/isolinux.cfg > isolinux.cfg.new
mv isolinux.cfg.new iso-root/isolinux/isolinux.cfg
```

Rebuild the ISO. Keep the original volume label so `inst.stage2=hd:LABEL=...` still works.

```sh
genisoimage -quiet \
  -o Rocky-9-x86_64-minimal-unattended.iso \
  -V 'Rocky-9-7-x86_64-dvd' \
  -R -J -joliet-long \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e images/efiboot.img \
  -no-emul-boot \
  iso-root
```

## Create the VM

Copy the ISO to the FreeBSD host:

```sh
scp Rocky-9-x86_64-minimal-unattended.iso f3.lan.buetow.org:/tmp/
ssh f3.lan.buetow.org 'doas mv /tmp/Rocky-9-x86_64-minimal-unattended.iso /zroot/bhyve/.iso/'
```

Create the guest. Use unique UUID and MAC values.

```sh
VM=rocky
doas vm create "$VM"
doas truncate -s 100G /zroot/bhyve/$VM/disk0.img
UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
MAC="58:9c:fc:$(openssl rand -hex 3 | sed 's/../:&/g' | sed 's/^://')"

doas sh -c "cat > /zroot/bhyve/$VM/$VM.conf" <<EOF
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
uuid="$UUID"
network0_mac="$MAC"
EOF
```

Start the install:

```sh
doas vm install "$VM" Rocky-9-x86_64-minimal-unattended.iso
doas vm list
```

VNC is normally available on `f3.lan.buetow.org:5900`. It is useful if Anaconda waits for input.

## Autostart Policy

For the f3 `rocky` VM, `rocky` is the only VM that starts by default:

```sh
doas sysrc vm_list="rocky"
doas sysrc vm_delay="5"
```

If another host should keep existing VMs in autostart, preserve them explicitly:

```sh
doas sysrc vm_list="existing_vm new_vm"
```

## Verify

Wait for the installer to reboot. Root SSH should come up after the installed OS boots:

```sh
ssh root@192.168.1.123 'hostname; cat /etc/rocky-release; ip -4 -brief addr; systemctl is-active sshd'
```

Expected for the f3 `rocky` VM:

```text
rocky
Rocky Linux release 9.7 (Blue Onyx)
enp0s5 UP 192.168.1.123/24
active
```

Host-side checks:

```sh
ssh f3.lan.buetow.org 'doas vm list; doas vm info rocky; doas sysrc -n vm_list'
```

## Cleanup

Keep the root password file private if it is still needed:

```sh
chmod 600 /tmp/rocky-bhyve-build/root-password.txt
```

Remove temporary extracted ISO trees once the VM is verified.
