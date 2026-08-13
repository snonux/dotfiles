---
name: gogios
description: Deploy the Gogios project using the established package-repo and rex workflow. Use when the user asks to build, deploy, install, or update Gogios, or mentions gogios deployment steps.
---

# Gogios

## When to Use

Use this skill when working on Gogios deployment tasks, especially when the request involves:
- Building and publishing a Gogios package for OpenBSD
- Deploying Gogios to an OpenBSD target
- Running the frontend install workflow via `rex`
- Repeating the standard "build then install" deployment sequence

## Instructions

Follow this workflow in order:

1. Build, sign, and upload the OpenBSD package from the project context:
   - Run: `cd ~/git/conf/packages && make pkg-openbsd NAME=gogios SRC=/home/paul/git/gogios`
   - This cross-compiles from `internal/version.go`'s `Version`, packages, signs with signify, and uploads to the custom package repo (`pkgrepo.f3s.buetow.org`).

2. Move to the frontend repo directory:
   - Change directory to: `~/git/conf/frontends`

3. Run the Gogios install task:
   - Run: `rex gogios_install`
   - This runs `pkg_add -u gogios` (or `pkg_add gogios` if not yet installed) on each OpenBSD frontend.

## Notes

- Keep this sequence ordered: build/publish first, install second.
- If any command fails, stop and report the failing command with the error output before retrying.
- `pkg_add -u` only recognizes a new version as an update candidate if its `@comment pkgpath=... ftp=no` annotation matches the installed package's. The packaging script (`~/git/conf/packages/scripts/pkg-openbsd.sh`) passes `pkg_create -D FULLPKGPATH=local/<name>` to emit this correctly as of 2026-08-13 (gogios 1.4.5+). If `rex gogios_install` ever reports the old version after a build, the currently-installed package predates that fix and needs one explicit forced install to pick up the annotation (after that, `pkg_add -u` upgrades normally again):
  `ssh <host> 'export PKG_PATH="https://pkgrepo.f3s.buetow.org/openbsd/7.8/packages/amd64/"; doas pkg_delete gogios && doas pkg_add gogios-<version>'`
- Build/deploy for FreeBSD (if ever needed) uses the equivalent `make pkg-freebsd NAME=gogios SRC=/home/paul/git/gogios`, or `make pkg ...` for both OSes.
