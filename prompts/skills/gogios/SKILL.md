---
name: gogios
description: Deploy the Gogios project using the established package-repo and gonf workflow. Use when the user asks to build, deploy, install, or update Gogios, or mentions gogios deployment steps.
---

# Gogios

## When to Use

Use this skill when working on Gogios deployment tasks, especially when the request involves:
- Building and publishing a Gogios package for OpenBSD
- Deploying Gogios to an OpenBSD target
- Running the frontend install workflow via gonf (`~/git/conf/gonf.sh`)
- Repeating the standard "build then install" deployment sequence

## Instructions

Follow this workflow in order:

1. Build, sign, and upload the OpenBSD package from the project context:
   - Run: `cd ~/git/conf/packages && make pkg-openbsd NAME=gogios SRC=/home/paul/git/gogios`
   - This cross-compiles from `internal/version.go`'s `Version`, packages, signs with signify, and uploads to the custom package repo (`pkgrepo.f3s.buetow.org`).

2. Move to the conf repo root:
   - Change directory to: `~/git/conf`

3. Run the Gogios gonf task on both OpenBSD frontends (cluster `frontends`: blowfish, fishfinger):
   - Run: `./gonf.sh cluster frontends frontends_gogios`
   - Preview first with `./gonf.sh cluster -n frontends frontends_gogios` if unsure.
   - `frontends_gogios` declares `Package("gogios", ..., IsLatest)` with the custom repo `PKG_PATH`, so it installs gogios when absent and runs `pkg_add -u gogios` otherwise. It is the full Gogios setup: the `_gogios` account, runtime/status directories, `gogios.json`, the `check_shuriken_age` plugin (needs the `~/git/shuriken.sh` checkout on the controller) and the `_gogios` crontab. It converges idempotently, so after a package build a rerun normally changes only the package.

## Notes

- Keep this sequence ordered: build/publish first, install second.
- If any command fails, stop and report the failing command with the error output before retrying.
- `pkg_add -u` only recognizes a new version as an update candidate if its `@comment pkgpath=... ftp=no` annotation matches the installed package's. The packaging script (`~/git/conf/packages/scripts/pkg-openbsd.sh`) passes `pkg_create -D FULLPKGPATH=local/<name>` (gogios 1.4.5+, since 2026-08-13; dtail uses the same scheme since 2026-09-26). An installed package without it needs one forced reinstall (`doas pkg_delete gogios && doas pkg_add gogios-<version>` with the custom `PKG_PATH`).
- A plain `doas pkg_add -u` needs `PKG_PATH="installpath:<custom repo>"` (set in root's and rex's `.profile` by `frontends_pkg_repo`); with only `/etc/installurl` it prints `Couldn't find updates for ... gogios-<version>`.
- Building for FreeBSD (if ever needed) uses the equivalent `make pkg-freebsd NAME=gogios SRC=/home/paul/git/gogios`, or `make pkg ...` for both OSes. There is no gonf task that installs Gogios on FreeBSD hosts (`frontends_gogios` covers the OpenBSD frontends only), so a FreeBSD install is a manual `doas pkg install gogios`.
