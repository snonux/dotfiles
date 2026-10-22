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
2. SCPs binary + packaging script to target host (f0 for FreeBSD, the local OpenBSD VM on earth for OpenBSD)
3. Runs the packaging script via SSH (`pkg create` / `pkg_create`)
4. OpenBSD packages must be signed with signify on the local VM and verified in full with standalone `signify -Vz -p /etc/signify/custom-pkg.pub -x "$artifact" >/dev/null` before upload; missing keys or failed signing/verification stop the build
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
- **NetBSD**: cross-compile with `CGO_ENABLED=0 GOOS=netbsd GOARCH=arm64 -tags nozstd`; packaging (`pkg_create`) runs natively on pi0 because `+BUILD_INFO` must match the target host
- **Rocky Linux**: built locally on earth (x86_64) and on pi2 (aarch64 via rpmbuild)

## Manual Packaging Reference

### FreeBSD (on f0)

```sh
pkg create -M +MANIFEST -p plist -r stagedir -o output/All
pkg repo output/   # regenerates repo metadata
doas cp -Rf output/* /data/nfs/k3svolumes/pkgrepo/freebsd/FreeBSD:15:amd64/latest/
```

### OpenBSD (on the local build VM on earth)

Prefer `make pkg-openbsd` / `make dtail-openbsd`: they assemble, sign, verify
and retrieve only signed artifacts before publication. For manual work inside
the VM, first run `pkg_create` into an unsigned staging directory, then:

```sh
mkdir -p signed
doas pkg_sign -s signify2 -s /etc/signify/custom-pkg.sec \
    -o signed output/package-name-1.0.tgz
signify -Vz -p /etc/signify/custom-pkg.pub \
    -x signed/package-name-1.0.tgz >/dev/null
```

From earth, retrieve **signed/package-name-1.0.tgz** with strict host-key
checking on port 2222, then transfer that artifact through f0 to the OpenBSD
PV. The unsigned output directory is never a publication source.
`pkg_info -C` is metadata display, not a pinned-key/full-stream verification
gate. Native acceptance remains pending live approval: valid succeeds;
unsigned, different signer and corruption after 64 KiB of the compressed
artifact must fail. See conf `packages/keys/README.md` for the full checklist.

### NetBSD (on pi0)

```sh
# pkg_* tools are in /usr/sbin (not in the non-interactive SSH PATH)
# Files staged under stagedir (-p), installed relative to / (-I);
# @owner root / @group wheel in the packing list keeps installed files root-owned.
/usr/sbin/pkg_create \
    -B build-info \
    -c commentfile \
    -d descfile \
    -f packing-list \
    -I / \
    -p stagedir \
    output/package-name-1.0.tgz
# pkg_summary.gz enables pkgin (pkg_add alone doesn't need it)
/usr/sbin/pkg_info -X output/*.tgz | gzip -9 > output/pkg_summary.gz
# Copy to PV via f0
scp -P 22 output/* f0.lan.buetow.org:/tmp/
ssh -p 22 f0.lan.buetow.org "doas cp /tmp/package-name-1.0.tgz /tmp/pkg_summary.gz /data/nfs/k3svolumes/pkgrepo/netbsd/11.0/packages/aarch64/"
```

NetBSD package versions must not contain dashes (the last dash separates the
package name from the version), so DTail's `4.3.2-ng` becomes `4.3.2ng`.

## Install/Update on Frontends via gonf

```sh
cd ~/git/conf
./gonf.sh cluster frontends frontends_gogios   # install/update + full setup on blowfish + fishfinger (OpenBSD)
./gonf.sh cluster frontends frontends_d_tail   # same for DTail (package, _dserver, daily hooks, dserver)
```

`frontends_gogios` declares the package with `IsLatest` and the custom repo
`PKG_PATH`, so it installs gogios when absent and runs `pkg_add -u` otherwise;
it also converges the `_gogios` account, `gogios.json`, plugins and crontab.
The gonf tasks cover the OpenBSD frontends only: there is no gonf task that
installs gogios on the FreeBSD hosts f0–f3 (install it by hand with `pkg`
there if ever needed).

## Signing-key custody and migration status (2026-10-22)

Canonical procedure and committed public halves:
`~/git/conf/packages/keys/README.md`. Earth owns private custody under
`~/.local/share/f3s-package-signing` (0700, private files 0600), with exact
foostore/KeePass recovery references for OpenBSD, FreeBSD RSA and Rocky GPG.
Vault Password fields contain single-line base64 of the full private files.
The dedicated local OpenBSD VM may receive the signify key via
`packages/buildvm/install-signing-key.sh`; no other builder, frontend or NFS
storage may receive private signing keys. Its SSH forwarding must bind only
127.0.0.1 and its host key must already be verified in known_hosts.

Local tooling and public keys are prepared. Explicit live approval remains
required to restart/provision the VM, verify a package, and remove historical
private copies from frontends/NFS after confirming recovery. Frontend clients
retain public trust only. The old signify identity has been preserved for
compatibility; reduced custody does not revoke previously copied keys.
FreeBSD/Rocky signing and client enforcement are later tasks (`ym3`, `zm3`,
`0n3`); existing publication recipes remain unsigned there until that rollout.

### Disk, SSH and backup custody gates (2026-10-22)

The VM disk must be an operator-owned regular non-symlink, mode 0600. Setup,
start, direct expect installation and signing-key installation enforce this;
the existing stopped disk was corrected locally to 0600. Bootstrap pbuild
password authentication must be disabled before key transfer: password and
keyboard-interactive off, root SSH off, AuthenticationMethods publickey, and
UseDNS no. The installer verifies a fresh key login, global/Match-effective
settings and active-daemon method advertisements; a missing reload fails.
Follow the exact two-session hardening/recovery sequence in conf
`packages/keys/README.md` only after explicit live approval. No VM SSH setting
was changed in local preparation.

The full original `/data/nfs` filename scan completed and found a retained
0644 private copy at f0
`/data/nfs/earthdata/backups/earthhome/git/conf/packages/buildvm/custom-pkg.sec`.
It remains pending approved cleanup alongside fishfinger's private key. The
current installed earth home-backup targets f2's encrypted earth-backup;
`/git/` already excludes the legacy checkout key/disk. A targeted
`f3s-package-signing/` exclusion now prevents raw new custody/GnuPG backups,
with receiver protection preserving existing copies for approved cleanup.
No backup was run. Inventory current backups, replicas and retained snapshots;
removing one active file cannot establish retirement of historical exposure.
Signify trust rotation remains a separate reviewed operation.
