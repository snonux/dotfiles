---
name: pkgrepo
description: Reference skill for the homelab package repositories behind pkgrepo.f3s.buetow.org. Covers FreeBSD pkg, OpenBSD pkg_add, Rocky Linux dnf repos, PV layout, nginx/ArgoCD wiring, DTail package publishing, and client repo configuration. Use when publishing packages, troubleshooting repository access or metadata, or deciding how packages should be installed from the custom repo.
---

# Package Repo Reference

Use this skill when the task is specifically about the custom package repositories rather than the broader f3s homelab.

## When to Use

- Publishing or updating packages in `pkgrepo.f3s.buetow.org`
- Troubleshooting repo layout, metadata, or HTTP exposure
- Configuring FreeBSD, OpenBSD, or Rocky Linux clients to install from the custom repo
- Working on DTail package publishing and installation through the repo

## Reference Files

- [Package Repositories](references/package-repos.md) — repo layout, PV paths, nginx exposure, client config, and DTail package workflows

## Scope

This skill owns package repository details that used to live under `f3s`.

Use `f3s` alongside this skill when the task depends on broader host-role or cluster context, especially:

- `f0` as the FreeBSD NFS/PV host for `/data/nfs/k3svolumes/pkgrepo/`
- `fishfinger` and `blowfish` as the OpenBSD frontend hosts
- `r0-r2` as Rocky Linux x86_64 bhyve VMs
- `pi0-pi3` as Rocky Linux aarch64 Raspberry Pi nodes
- `earth` as the Fedora laptop used for package publication and verification
