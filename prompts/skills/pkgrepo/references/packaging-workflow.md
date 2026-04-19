# Packaging Workflow

Build scripts live in `~/git/conf/packages/`. The Makefile cross-compiles Go binaries on Linux, ships them to target hosts for native packaging, and uploads to the PV.

## Single-Binary Go Packages

For pure Go packages (no CGo), cross-compilation from Linux works for both FreeBSD and OpenBSD.

### Build and upload

```sh
cd ~/git/conf/packages

# Both FreeBSD and OpenBSD
make pkg NAME=gogios SRC=/home/paul/git/gogios \
    COMMENT="Monitoring tool with email alerts and HTML status page" \
    DESC="Gogios is a lightweight monitoring tool written in Go."

# Single OS
make pkg-freebsd NAME=gogios SRC=/home/paul/git/gogios
make pkg-openbsd NAME=gogios SRC=/home/paul/git/gogios
```

### How it works

1. Cross-compiles on Linux (`GOOS=freebsd/openbsd GOARCH=amd64`)
2. SCPs binary + packaging script to target host (f0 for FreeBSD, fishfinger for OpenBSD)
3. Runs the packaging script via SSH (`pkg create` / `pkg_create`)
4. OpenBSD packages are signed with signify automatically
5. FreeBSD repo metadata is regenerated with `pkg repo`
6. Packages are copied to the PV at `/data/nfs/k3svolumes/pkgrepo/`

### Required Makefile variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NAME` | Package name | `gogios` |
| `SRC` | Go project root (must have `cmd/<NAME>/main.go` and `internal/version.go`) | `/home/paul/git/gogios` |

### Optional Makefile variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COMMENT` | `$(NAME)` | One-line package description |
| `DESC` | `$(NAME)` | Longer description |
| `MAINTAINER` | `paul@buetow.org` | Maintainer email |
| `WWW` | `https://buetow.org` | Project URL |
| `ENTRY` | `cmd/$(NAME)/main.go` | Go main package path relative to SRC |

### Version detection

Version is read automatically from `$(SRC)/internal/version.go` — expects a `Version` constant like `const Version = "v1.4.1"`. The `v` prefix is stripped.

## CGo Packages

Cross-compilation from Linux fails for CGo (e.g. packages with DataDog/zstd). Use native builds instead:

- **OpenBSD**: native build on the local QEMU/KVM build VM (see [openbsd-build-vm.md](openbsd-build-vm.md))
- **FreeBSD**: cross-compile with `CGO_ENABLED=0 -tags nozstd` — disables zstd support but allows static cross-compile
- **Rocky Linux**: built locally on earth (x86_64) and on pi0 (aarch64 via rpmbuild)

## Manual Packaging Reference

### FreeBSD (on f0)

```sh
pkg create -M +MANIFEST -p plist -r stagedir -o output/All
pkg repo output/   # regenerates repo metadata
doas cp -Rf output/* /data/nfs/k3svolumes/pkgrepo/freebsd/FreeBSD:15:amd64/latest/
```

### OpenBSD (on fishfinger)

```sh
pkg_create \
    -D COMMENT="Package description" \
    -d descfile \
    -f packing-list \
    -B stagedir \
    -p / \
    output/package-name-1.0.tgz
# Copy to PV via f0
scp package.tgz f0.lan.buetow.org:/tmp/
ssh -p 22 f0.lan.buetow.org "doas cp /tmp/package.tgz /data/nfs/k3svolumes/pkgrepo/openbsd/7.8/packages/amd64/"
```

## Install/Update on Frontends via Rex

```sh
cd ~/git/conf/frontends
rex gogios_install   # installs or updates gogios on blowfish + fishfinger (OpenBSD) and f0-f3 (FreeBSD)
rex gogios           # full setup: gogios_install + config + cron
```

The `gogios_install` Rex task auto-detects the OS and uses `pkg install` (FreeBSD) or `pkg_add` (OpenBSD).
