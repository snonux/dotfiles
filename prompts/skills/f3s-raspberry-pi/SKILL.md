---
name: f3s-raspberry-pi
description: Reference skill for the four Raspberry Pi 3 nodes of the f3s homelab, pi0/pi1 run NetBSD 10.1 (aarch64) serving static f3s.buetow.org / snonux.foo via bozohttpd behind OpenBSD relayd over WireGuard; pi2/pi3 run Rocky Linux 9 with Pi-hole in Docker and LAN wildcard DNS (`*.f3s.lan.buetow.org` to 192.168.1.138). Covers doas/pkgin bootstrap, bozohttpd vhosting, npf, uptimed, content sync, and the doas-alias shutdown pitfall. Use when configuring or troubleshooting the Pi nodes, the static site, or Pi-hole/LAN DNS. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# f3s Raspberry Pi Nodes

The four Raspberry Pi 3 nodes of the f3s homelab. The master host/IP inventory
(pi0–pi3 rows) lives in the [`f3s`](../f3s/SKILL.md) hub's Host-IP table.

## When to Use

- Configuring or troubleshooting pi0–pi3 (NetBSD static site pair, or Rocky Pi-hole pair)
- The static `f3s.buetow.org` / `snonux.foo` site (bozohttpd, relayd forwarding, vhosts)
- Pi-hole and `*.f3s.lan.buetow.org` LAN wildcard DNS
- For the WireGuard mesh these depend on, see the [`f3s`](../f3s/SKILL.md) hub's `wireguard.md`; for DTail/dserver on the Pis, [`f3s-dtail`](../f3s-dtail/SKILL.md); for building the NetBSD dserver package, the [`pkgrepo`](../pkgrepo/SKILL.md) skill.

## Node roles

`pi2`/`pi3` run Rocky Linux 9.2 (Blue Onyx) aarch64 from the SIG/AltArch image (`RockyLinuxRpi_9-latest.img.xz`). `pi0` and `pi1` run **NetBSD 10.1** (evbarm-aarch64). Each Rocky Pi has:

- User `paul` with passwordless sudo and SSH key auth
- Static IP on eth0 via NetworkManager
- Hostname `piN.lan.buetow.org`
- Filesystem expanded with `rootfs-expand`
- Default `rocky` user still present (password: `rockylinux`)
- No GRUB — boots via Pi's native bootloader (`/boot/cmdline.txt`)
- Custom RPi kernel from the `rockyrpi` repo

`pi0`/`pi1` (NetBSD) differ: user `paul` in `wheel`, privilege escalation via a **real `doas`** (pkgsrc `security/doas`, `permit nopass :wheel`) — not the `alias doas=sudo` shell alias `pi2`/`pi3` carry in `/etc/profile.d/doas.sh`, which doesn't expand in the non-interactive shell an SSH command runs in and so silently breaks `wol-f3s shutdown-pis`/`shutdown-all` for the Rocky Pis (`doas poweroff` resolves to nothing) — only the NetBSD nodes actually work with that script today. Config repo home for NetBSD-specific setup: `f3s/pi-netbsd/`. Service setup details: [NetBSD Pi Setup](references/bootstrap-netbsd-pi.md).

Current role split:

- `pi0` and `pi1` serve static `f3s.buetow.org`/`snonux.foo` content behind OpenBSD `relayd` over WireGuard. WireGuard peers are `blowfish`, `fishfinger`, **and `rocky`** (not gateway-only to just the two frontends, despite older docs here). All rc.d services (`wireguard`, `bozohttpd`, `uptimed`, `npf`, `dserver`) and both crontabs are enabled via `rc.conf` and come back automatically on reboot.
- `pi2` and `pi3` run **Pi-hole** in Docker (`network_mode: host`, `~/pihole` on each host). Tracked dnsmasq LAN wildcard: **`f3s/pihole/docker-pi/`** in the conf repo; details in [references/pihole-pi.md](references/pihole-pi.md).

## Webserver (pi0/pi1 static site)

`pi0`/`pi1` serve `f3s.buetow.org`/`snonux.foo` with **bozohttpd** (NetBSD base) behind
the OpenBSD `relayd` frontends. Vhosting is directory-based: a vhost needs a directory
*literally* named after the hostname (`snonux.foo/`, with `www.snonux.foo` a symlink),
and `-X` enables directory indexing. Because `relayd` **cannot rewrite URL paths** (it
forwards the original path intact), each domain is mapped to its docroot subdir via the
`Host` header. Docroot `/var/www/html`; `pi1` syncs the docroot hourly from `pi0` (the
source of truth); SSH `paul@piN.lan.buetow.org -p 22`.

The full bozohttpd setup — the custom `/etc/rc.d/bozohttpd`, the `-V` fallback
system-hostname redirect pitfall, and the self-referencing vhost symlink fix — is the
canonical detail in [references/bootstrap-netbsd-pi.md](references/bootstrap-netbsd-pi.md#webserver--bozohttpd).

## Reference Files

- [NetBSD Pi Setup](references/bootstrap-netbsd-pi.md) — how services are installed on `pi0`/`pi1` (NetBSD): doas/pkgin bootstrap, WireGuard via userspace `wireguard-go` (no native `wg(4)`), bozohttpd (`-X` dir-listing, vhost symlinks), uptimed from source, npf firewall, content-sync. dserver (DTail) is installed from the custom pkgrepo — see the [`pkgrepo`](../pkgrepo/SKILL.md) skill's `dtail-package.md`.
- [Pi-hole on Pis](references/pihole-pi.md) — **pi2/pi3** Docker Pi-hole, **`~/pihole`**, **`*.f3s.lan.buetow.org` → 192.168.1.138**, paths under **`f3s/pihole/docker-pi/`**
