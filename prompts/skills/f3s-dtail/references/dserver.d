# dserver on f3s (index)

- **r0–r2 Rocky bhyve / k3s VMs** — install context and SSH notes: [Rocky Linux VMs – DTail (dserver) on r0–r2](rocky-linux-vms.md#dtail-dserver-on-r0r2)
- **pi0–pi1 NetBSD Pis** — dserver installed from the custom pkgrepo (`dtail-4.3.2ng` package): build with `make dtail-netbsd` in `~/git/conf/packages` (cross-compile netbsd/arm64, package natively on pi0, upload to pkgrepo), deploy via `pkg_add https://pkgrepo.f3s.buetow.org/netbsd/10.1/packages/aarch64/dtail-<version>.tgz`. Full build/install/rc.d/npf details and gotchas: `f3s-pkgrepo` skill's `dtail-package.md`
- **Full DTail reference** (NetBSD + Rocky Pis, r VMs amd64, firewalld, key cache, clients): [dtail.md](dtail.md)

Upstream repo: `https://codeberg.org/snonux/dtail` — `doc/installation.md`, `examples/`.
