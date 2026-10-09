# f3s DTail / dserver (area index)

Distributed log access (DTail) via `dserver` across the f3s fleet. This area owns
the **runtime deployment/operations**; package *building/publishing* lives in
[Package repo — DTail package](pkgrepo/dtail-package.md).

## When to Use

- Deploying, configuring, or troubleshooting `dserver` on homelab hosts (Pis, r0–r2)
- SSH-on-2222 access, permissions/key-cache, firewall (firewalld/npf) rules, systemd timers
- For building the `dtail` package (esp. the NetBSD build), use [Package repo](pkgrepo.md); for the Pi nodes themselves, [Raspberry Pis](raspberry-pi.md); for hosts/IPs, the [hub](../SKILL.md).

## Overview

Distributed log access (`dcat`/`dtail`/`dgrep`/`dmap`) over SSH on port **2222** (not
sshd's 22), by architecture: **pi2/pi3** linux/arm64, **pi0/pi1** netbsd/arm64 (installed
from the `dtail` package in the custom [package repo](pkgrepo.md)), **r0–r2** k3s
Rocky VMs linux/amd64. The recurring gotchas — installing as `root`, listing `root` in
`Server.Permissions.Users`, mirroring `/root/.ssh/authorized_keys` into the key cache
(the cache script only walks `/home/*`), and opening 2222 in firewalld/npf — plus the
exact per-host cross-build commands are the canonical detail in
[Deployment](dtail/deployment.md).

## Topic Files

- [Deployment](dtail/deployment.md) — full deployment detail: Pis **arm64** vs r0–r2 **amd64**, r-VM **root** + `root.authorized_keys` cache, firewalld **2222**, systemd timers (section **dserver on r0, r1, r2**), cross-compiling, installation checklist, client examples, verified lab state

## Where dserver Lives Per Host Type

- **r0–r2 Rocky bhyve / k3s VMs** — install context and SSH notes: [Rocky Linux VMs – DTail (dserver) on r0–r2](vms/rocky-linux-vms.md#dtail-dserver-on-r0r2)
- **pi0–pi1 NetBSD Pis** — dserver installed from the custom pkgrepo (`dtail-4.3.2ng` package): build with `make dtail-netbsd` in `~/git/conf/packages` (cross-compile netbsd/arm64, package natively on pi0, upload to pkgrepo), deploy via `pkg_add https://pkgrepo.f3s.buetow.org/netbsd/11.0/packages/aarch64/dtail-<version>.tgz`. Full build/install/rc.d/npf details and gotchas: [Package repo — DTail package](pkgrepo/dtail-package.md)
- **Full DTail reference** (NetBSD + Rocky Pis, r VMs amd64, firewalld, key cache, clients): [Deployment](dtail/deployment.md)

Upstream repo: `https://github.com/snonux/dtail` — `doc/installation.md`, `examples/`.
