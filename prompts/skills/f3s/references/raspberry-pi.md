# f3s Raspberry Pi Nodes (area index)

The four Raspberry Pi 3 nodes of the f3s homelab. The master host/IP inventory
(pi0–pi3 rows) lives in the [hub's Host-IP table](../SKILL.md#quick-reference-host-ips).

## When to Use

- Configuring or troubleshooting pi0–pi3 (NetBSD static site pair, or Rocky Pi-hole pair)
- The static `f3s.buetow.org` / `snonux.foo` site (bozohttpd, relayd forwarding, vhosts)
- Pi-hole and `*.f3s.lan.buetow.org` LAN wildcard DNS
- For the WireGuard mesh these depend on, see [Network — WireGuard](network/wireguard.md); for DTail/dserver on the Pis, [DTail](dtail.md); for building the NetBSD dserver package, [Package repo — DTail package](pkgrepo/dtail-package.md).

## Topic Files

NetBSD on pi0/pi1 (five files; pick the service):

- [NetBSD base](raspberry-pi/netbsd-base.md) — base state, doas/pkgin bootstrap, major-version upgrade recovery lessons, the end-to-end verification checklist. **One node at a time**: never take pi0 and pi1 down together.
- [NetBSD WireGuard](raspberry-pi/netbsd-wireguard.md) — userspace `wireguard-go` deployment (no native `wg(4)`), the 10.1 module finding
- [NetBSD bozohttpd](raspberry-pi/netbsd-bozohttpd.md) — bozohttpd (`-X` dir-listing, vhost symlinks, CGI argument order), the custom rc.d script, static content sync from pi0 to pi1
- [NetBSD uptimed](raspberry-pi/netbsd-uptimed.md) — uptimed built from source, its rc.d script and `ntpdate` ordering, goprecords upload
- [NetBSD npf](raspberry-pi/netbsd-npf.md) — the npf firewall (not firewalld), safe enable procedure, port 2222 for dserver

Rocky Linux on pi2/pi3:

- [Pi-hole on Pis](raspberry-pi/pihole-pi.md) — **pi2/pi3** Docker Pi-hole, **`~/pihole`**, **`*.f3s.lan.buetow.org` → 192.168.1.138**, paths under **`f3s/pihole/docker-pi/`**

dserver (DTail) on pi0/pi1 is installed from the custom pkgrepo — see [Package repo — DTail package](pkgrepo/dtail-package.md).

## Node roles

`pi2`/`pi3` run Rocky Linux 9.2 (Blue Onyx) aarch64 from the SIG/AltArch image (`RockyLinuxRpi_9-latest.img.xz`). `pi0` and `pi1` run **NetBSD 11.0** (evbarm-aarch64). Each Rocky Pi has:

- User `paul` with passwordless sudo and SSH key auth
- Static IP on eth0 via NetworkManager
- Hostname `piN.lan.buetow.org`
- Filesystem expanded with `rootfs-expand`
- Default `rocky` user still present (password: `rockylinux`)
- No GRUB — boots via Pi's native bootloader (`/boot/cmdline.txt`)
- Custom RPi kernel from the `rockyrpi` repo

`pi0`/`pi1` (NetBSD) differ: user `paul` in `wheel`, privilege escalation via a **real `doas`** (pkgsrc `security/doas`, `permit nopass :wheel`) — not the `alias doas=sudo` shell alias `pi2`/`pi3` carry in `/etc/profile.d/doas.sh`, which doesn't expand in the non-interactive shell an SSH command runs in, so `ssh paul@pi2 "doas poweroff"` silently resolves to nothing. Use `sudo` on the Rocky Pis when scripting. Config repo home for NetBSD-specific setup: `f3s/pi-netbsd/`. Service setup details: [NetBSD base](raspberry-pi/netbsd-base.md).

**Powering the f-hosts from a Pi is now `f3sctl`, not `wol-f3s`.** `wol-f3s` was
removed from pi0, pi1, pi2 and pi3 on 2026-08-09; only earth still has a copy.
pi0/pi1 run `f3sctl` (NetBSD package, plus the CGI at `/cgi-bin/f3sctl`);
pi2/pi3 have no power tooling at all and need none. Note that **`f3sctl` never
powers a Raspberry Pi** — powering pi0/pi1 off would remove the only way to
power anything back on — so shutting a Pi down is a deliberate manual
`ssh <pi> "doas poweroff"` (NetBSD) / `sudo poweroff` (Rocky).

Current role split:

- `pi0` and `pi1` serve static `f3s.buetow.org`/`snonux.foo` content behind OpenBSD `relayd` over WireGuard. WireGuard peers are `blowfish`, `fishfinger`, **and `rocky`** (not gateway-only to just the two frontends, despite older docs here). All rc.d services (`wireguard`, `bozohttpd`, `uptimed`, `npf`, `dserver`) and both crontabs are enabled via `rc.conf` and come back automatically on reboot.
- `pi2` and `pi3` run **Pi-hole** in Docker (`network_mode: host`, `~/pihole` on each host). Tracked dnsmasq LAN wildcard: **`f3s/pihole/docker-pi/`** in the conf repo; details in [Pi-hole on Pis](raspberry-pi/pihole-pi.md).

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
canonical detail in [NetBSD bozohttpd](raspberry-pi/netbsd-bozohttpd.md#webserver--bozohttpd).
