# DTail Package

DTail is a multi-binary package (6 binaries + config + service script). There are separate targets for each OS.

## Build Commands

```sh
cd ~/git/conf/packages
make dtail-openbsd   # OpenBSD: native build on QEMU/KVM VM (CGo/zstd supported)
make dtail-freebsd   # FreeBSD: cross-compiled on Linux (CGO_ENABLED=0, nozstd — .zst logs unsupported)
make dtail-rocky     # Rocky Linux: x86_64 + aarch64 RPMs + repodata
```

## Package Contents by OS

### OpenBSD (blowfish, fishfinger)

| File | Source template |
|------|----------------|
| `/usr/local/bin/dserver`, `dcat`, `dgrep`, `dmap`, `dtail`, `dtailhealth` | built natively on build VM |
| `/etc/dserver/dtail.json` | `frontends/etc/dserver/dtail.json.tpl` |
| `/etc/rc.d/dserver` | `frontends/etc/rc.d/dserver.tpl` |
| `/usr/local/bin/dserver-update-key-cache.sh` | `frontends/scripts/dserver-update-key-cache.sh.tpl` (ksh) |

### FreeBSD (f0–f3)

| File | Source template |
|------|----------------|
| `/usr/local/bin/dserver`, `dcat`, `dgrep`, `dmap`, `dtail`, `dtailhealth` | cross-compiled `GOOS=freebsd CGO_ENABLED=0 -tags nozstd` |
| `/usr/local/etc/dserver/dtail.json` | `frontends/etc/dserver/dtail-freebsd.json.tpl` |
| `/usr/local/etc/rc.d/dserver` | `frontends/etc/rc.d/dserver-freebsd.tpl` |
| `/usr/local/bin/dserver-update-key-cache.sh` | `frontends/scripts/dserver-update-key-cache-freebsd.sh.tpl` (sh) |

**FreeBSD config note:** `dtail-freebsd.json.tpl` uses **absolute paths** for `CacheDir` and `HostKeyFile` (`/var/run/dserver/cache/...`). FreeBSD's `daemon(8)` resets CWD to `/`, so the relative `"cache"` in the standard template resolves to `/cache` — silently breaking key lookup.

### Rocky Linux (r0–r2 amd64, pi0–pi3 aarch64)

| File |
|------|
| `/usr/local/bin/dserver`, `dcat`, `dgrep`, `dmap`, `dtail`, `dtailhealth` |
| `/usr/local/bin/dserver-update-key-cache.sh` |
| `/etc/dserver/dtail.json` |
| `/usr/lib/systemd/system/dserver.service` |
| `/usr/lib/systemd/system/dserver-update-keycache.service` |
| `/usr/lib/systemd/system/dserver-update-keycache.timer` |

Rocky notes:
- Key-cache helper handles both `/root/.ssh/authorized_keys` and `/home/*/.ssh/authorized_keys` — `root` works on r0–r2 without manual cache copy
- `dserver.service` includes `RuntimeDirectory=dserver` and `ExecStartPre` to recreate `/var/run/dserver` (tmpfs) on Rocky
- Repo is unsigned (`gpgcheck=0`)
- `aarch64` RPM is built on pi0 — Fedora's rpmbuild refuses to emit `aarch64` binary RPMs from an x86_64 host

## Install / Update

### OpenBSD (via Rex)

```sh
cd ~/git/conf/frontends
rex dtail_install   # install or update from custom repo
rex dtail           # full setup: install + _dserver user + daily cron + service start
```

### FreeBSD (manual, f0–f3)

```sh
# Custom repo must already be configured (see client-setup.md)
doas pkg install dtail          # first install
doas pkg install -fy dtail      # force reinstall (same version)

# Create service user (once per host)
doas pw useradd dserver -d /var/run/dserver -s /usr/sbin/nologin

# Enable and start dserver
doas sysrc dserver_enable=YES
doas service dserver start

# Populate key cache immediately (also runs daily via periodic)
doas /usr/local/bin/dserver-update-key-cache.sh

# Register daily key cache refresh
doas mkdir -p /usr/local/etc/periodic/daily
printf '%s\n%s\n' '#!/bin/sh' '/usr/local/bin/dserver-update-key-cache.sh' | \
  doas tee /usr/local/etc/periodic/daily/200.dserver-update-key-cache > /dev/null
doas chmod 755 /usr/local/etc/periodic/daily/200.dserver-update-key-cache
```

**FreeBSD gotchas:**
- `service dserver restart` clears `/var/run/dserver` (it's recreated by rc.d `start_precmd`, but the key cache files are gone) — always re-run `dserver-update-key-cache.sh` after any restart
- `pkg install -fy` replaces `/usr/local/etc/dserver/dtail.json` with the package version; local customisations are lost
- Avoid inline one-liners with `||`, `!`, or multi-quote strings over SSH to FreeBSD (csh) — pipe a script to `doas /bin/sh` instead or use separate SSH commands

### Rocky Linux (dnf)

```sh
# On r0–r2 (root) or pi0–pi3 (paul with sudo):
sudo dnf upgrade dtail
sudo systemctl restart dserver
sudo systemctl start dserver-update-keycache.service   # repopulate after restart
```

**Rocky gotcha:** A legacy `/etc/systemd/system/dserver-update-keycache.service` left from manual pre-RPM setup points to the old path `ExecStart=/var/run/dserver/update_key_cache.sh` and shadows the RPM-installed unit. Remove it on any host where the timer fails:

```sh
sudo rm -f /etc/systemd/system/dserver-update-keycache.service
sudo systemctl daemon-reload
sudo systemctl start dserver-update-keycache.service
```

This was cleaned up on all r0–r2 and pi0–pi3 on 2026-04-19.

## Client Usage from earth

```sh
# OpenBSD frontends
dcat --plain --noColor --trustAllHosts --user rex \
  --servers blowfish.buetow.org,fishfinger.buetow.org --files /etc/fstab

# FreeBSD hosts
dcat --plain --noColor --trustAllHosts --user paul \
  --servers f0.lan.buetow.org,f1.lan.buetow.org,f2.lan.buetow.org,f3.lan.buetow.org \
  --files /etc/fstab

# Rocky VMs (r0–r2, user root)
dcat --plain --noColor --trustAllHosts --user root \
  --servers r0.lan.buetow.org,r1.lan.buetow.org,r2.lan.buetow.org --files /etc/fstab

# Raspberry Pis (pi0–pi3, user paul)
dcat --plain --noColor --trustAllHosts --user paul \
  --servers pi0.lan.buetow.org,pi1.lan.buetow.org,pi2.lan.buetow.org,pi3.lan.buetow.org \
  --files /etc/fstab
```

## Verification State

| Date | Platform | Result |
|------|----------|--------|
| 2026-04-19 | FreeBSD f0–f3 | `dtail-4.3.2-ng` installed, dserver running under `daemon(8)`, `dcat /etc/fstab` ✓ (`--user paul`) |
| 2026-04-19 | OpenBSD blowfish, fishfinger | `dtail-4.3.2-ng` current, `dcat /etc/fstab` ✓ (`--user rex`) |
| 2026-04-19 | Rocky r0–r2 | `dtail-4.3.2-ng` current, dserver running, `dcat /etc/fstab` ✓ (`--user root`) |
| 2026-04-19 | Rocky pi0–pi3 | `dtail-4.3.2-ng` current, dserver running, `dcat /etc/fstab` ✓ (`--user paul`) |
