# Client Setup

How to configure each OS to install packages from `pkgrepo.f3s.buetow.org`.

## FreeBSD (f0–f3)

Custom repo is configured alongside the official FreeBSD repos.

File: `/usr/local/etc/pkg/repos/custom.conf`

```
custom: {
  url: "https://pkgrepo.f3s.buetow.org/freebsd/FreeBSD:15:amd64/latest",
  mirror_type: "NONE",
  signature_type: "NONE",
  enabled: yes
}
```

### Using packages

```sh
doas pkg update
doas pkg install <package-name>
doas pkg upgrade                  # upgrade all, including custom packages
doas pkg install -fy <package>    # force reinstall (same version)
```

### Setting up a new FreeBSD host

Pipe via stdin to avoid csh quoting issues:

```sh
cat <<'REPO' | ssh -p 22 <host>.lan.buetow.org 'doas mkdir -p /usr/local/etc/pkg/repos && doas tee /usr/local/etc/pkg/repos/custom.conf > /dev/null'
custom: {
  url: "https://pkgrepo.f3s.buetow.org/freebsd/FreeBSD:15:amd64/latest",
  mirror_type: "NONE",
  signature_type: "NONE",
  enabled: yes
}
REPO
```

## OpenBSD (blowfish, fishfinger)

Custom repo is configured via `PKG_PATH` in `/root/.profile`, deployed by `rex pkgrepo_setup`.
Official OpenBSD packages still install normally via `/etc/installurl`.

```sh
export PKG_PATH="https://pkgrepo.f3s.buetow.org/openbsd/7.8/packages/amd64/"
```

### Using packages

```sh
doas pkg_add <package>       # installs from custom repo (signed with signify)
doas pkg_add -u <package>    # update to latest version
```

### Setting up a new OpenBSD host

Two things needed:

1. **Signify public key** — copy from an existing host:
   ```sh
   scp rex@fishfinger.buetow.org:/etc/signify/custom-pkg.pub /tmp/
   scp /tmp/custom-pkg.pub rex@<newhost>:/tmp/
   ssh rex@<newhost> "doas cp /tmp/custom-pkg.pub /etc/signify/custom-pkg.pub"
   ```

2. **PKG_PATH** — run the Rex task from `~/git/conf/frontends`:
   ```sh
   rex pkgrepo_setup   # adds PKG_PATH to /root/.profile on all frontends
   ```

Update `PKG_PATH` whenever the OpenBSD version changes (currently 7.8).

### Package signing

OpenBSD packages are signed with `signify(1)` via `pkg_sign`:
- **Private key**: `/etc/signify/custom-pkg.sec` on fishfinger (build host)
- **Public key**: `/etc/signify/custom-pkg.pub` on all OpenBSD clients
- Signing happens automatically during `make pkg-openbsd` / `make pkg`
- `pkg_add` verifies the signature — no `-D unsigned` needed

## Rocky Linux (r0–r2, pi0–pi3)

Architecture-specific repo URLs:
- `https://pkgrepo.f3s.buetow.org/rockylinux/9/x86_64/`  (r0–r2)
- `https://pkgrepo.f3s.buetow.org/rockylinux/9/aarch64/` (pi0–pi3)

### Persistent repo file

Create `/etc/yum.repos.d/f3s-dtail.repo`:

```ini
[f3s-dtail]
name=f3s DTail
baseurl=https://pkgrepo.f3s.buetow.org/rockylinux/9/$basearch/
enabled=1
gpgcheck=0
repo_gpgcheck=0
```

Then:

```sh
sudo dnf makecache
sudo dnf install dtail
sudo dnf upgrade dtail
```

### Temporary one-off usage (no persistent repo file needed)

```sh
sudo dnf repoquery \
  --disablerepo='*' \
  --repofrompath=f3s-dtail,https://pkgrepo.f3s.buetow.org/rockylinux/9/$(uname -m)/ \
  --enablerepo=f3s-dtail \
  dtail
```

Do **not** pass `--repofrompath` when the persistent repo file already exists — dnf errors with "listed more than once".
