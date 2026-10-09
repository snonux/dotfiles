# f3s Package Repo (area index)

The custom package repositories behind `pkgrepo.f3s.buetow.org`: FreeBSD `pkg`,
OpenBSD `pkg_add`, NetBSD `pkg_add`, and Rocky Linux `dnf` repos. Use this area
when the task is specifically about the package repositories rather than the
broader f3s homelab.

## When to Use

- Publishing or updating packages in `pkgrepo.f3s.buetow.org`
- Troubleshooting repo layout, metadata, or HTTP exposure
- Configuring FreeBSD, OpenBSD, NetBSD, or Rocky Linux clients to install from the custom repo
- Working on DTail package publishing and installation through the repo

## Topic Files

- [Repo Architecture](pkgrepo/repo-architecture.md) — nginx/k3s setup, PV directory structure, SSH access, stale NFS handle fix, per-OS repo notes
- [Client Setup](pkgrepo/client-setup.md) — per-OS client repo configuration (FreeBSD, OpenBSD, NetBSD, Rocky Linux), new-host setup, package signing
- [Packaging Workflow](pkgrepo/packaging-workflow.md) — Makefile workflow for single-binary Go packages, CGo packages, manual packaging reference
- [DTail Package](pkgrepo/dtail-package.md) — multi-binary DTail package for all platforms, install/update steps, gotchas, client usage, verification
- [OpenBSD Build VM](pkgrepo/openbsd-build-vm.md) — QEMU/KVM build VM for native CGo compilation, day-to-day use, installer notes

## Host Roles That Matter Here

This area owns the package repository details. Host-role and cluster context
comes from the [hub](../SKILL.md) and the other areas, especially:

- `f0` as the FreeBSD NFS/PV host for `/data/nfs/k3svolumes/pkgrepo/` ([Storage](storage.md))
- `fishfinger` and `blowfish` as the OpenBSD frontend hosts
- `r0-r2` as Rocky Linux x86_64 bhyve VMs ([bhyve VMs](vms.md))
- `pi2-pi3` as Rocky Linux aarch64 Raspberry Pi nodes
- `pi0`/`pi1` as NetBSD aarch64 Raspberry Pi nodes (see [Raspberry Pis — NetBSD base](raspberry-pi/netbsd-base.md)) — NetBSD repo clients and the native NetBSD package build host (`pi0`)
- `earth` as the Fedora laptop used for package publication and verification
- `f0-f3` as FreeBSD hosts

Running dserver after the package is installed: [DTail](dtail.md).
