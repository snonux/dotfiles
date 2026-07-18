---
name: f3s-dtail
description: Reference skill for DTail/dserver deployment across the f3s fleet, distributed log access over SSH on port 2222 — Pis arm64 (NetBSD + Rocky) vs r0–r2 amd64, r-VM root + root.authorized_keys cache, firewalld/npf 2222 rules, systemd timers. Package building lives in the `pkgrepo` skill. Use when deploying, configuring, or troubleshooting dserver on homelab hosts. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# f3s DTail / dserver

Distributed log access (DTail) via `dserver` across the f3s fleet. This skill owns
the **runtime deployment/operations**; package *building/publishing* lives in the
sibling [`pkgrepo`](../pkgrepo/SKILL.md) skill (`dtail-package.md`).

## When to Use

- Deploying, configuring, or troubleshooting `dserver` on homelab hosts (Pis, r0–r2)
- SSH-on-2222 access, permissions/key-cache, firewall (firewalld/npf) rules, systemd timers
- For building the `dtail` package (esp. the NetBSD build), use [`pkgrepo`](../pkgrepo/SKILL.md); for the Pi nodes themselves, [`f3s-raspberry-pi`](../f3s-raspberry-pi/SKILL.md); for hosts/IPs, the [`f3s`](../f3s/SKILL.md) hub.

## Overview

Distributed log access (`dcat`/`dtail`/`dgrep`/`dmap`) over SSH on port **2222** (not
sshd's 22), by architecture: **pi2/pi3** linux/arm64, **pi0/pi1** netbsd/arm64 (installed
from the `dtail` package in the custom [`pkgrepo`](../pkgrepo/SKILL.md)), **r0–r2** k3s
Rocky VMs linux/amd64. The recurring gotchas — installing as `root`, listing `root` in
`Server.Permissions.Users`, mirroring `/root/.ssh/authorized_keys` into the key cache
(the cache script only walks `/home/*`), and opening 2222 in firewalld/npf — plus the
exact per-host cross-build commands are the canonical detail in
[references/dtail.md](references/dtail.md).

## Reference Files

- [DTail / dserver](references/dtail.md) — full deployment detail: Pis **arm64** vs r0–r2 **amd64**, r-VM **root** + `root.authorized_keys` cache, firewalld **2222**, systemd timers (section **dserver on r0, r1, r2**)
- [dserver.d](references/dserver.d) — index: links to the **Rocky r-VM DTail** subsection and full **dtail.md**
