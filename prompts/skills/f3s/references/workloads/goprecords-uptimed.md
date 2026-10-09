# Uptimed / uprecords via goprecords

Central uptime stats: **[goprecords](https://github.com/snonux/goprecords)** at
**`https://goprecords.f3s.buetow.org`** (k3s **services**, stats PVC,
**`goprecords-auth.db`**).

Client install, tokens, hourly schedules, and the **uptimed daemon** are
**gonf-managed** as one pair per OS group: applying the upload task always
converges uptimed first (`Needs`). Do not hand-edit upload units/cron or
uptimed conf/drop-ins on fleet hosts — change the recipes and re-apply.

## Gonf recipes (source of truth)

| Hosts | Repo | Upload task (pulls uptimed) | Uptimed task |
|--------|------|-----------------------------|--------------|
| blowfish, fishfinger | `~/git/conf` | `frontends_goprecords` | `frontends_uptimed` |
| f0–f3 | `~/git/conf` | `freebsd_goprecords_upload` | `freebsd_base_uptimed` |
| pi0, pi1 | `~/git/conf` | `netbsd_goprecords_upload` | `netbsd_goprecords_uptimed` |
| pi2, pi3 | `~/git/conf` | `rocky_goprecords_upload` | `rocky_goprecords_uptimed` |
| earth, zen | `~/git/dotfiles` | `home_goprecords_upload` | `system_uptimed` |

Shared client helper in conf: `gonf/goprecords/client.go` (script asset
`frontends/scripts/goprecords-upload-client.sh`). Shared Linux/NetBSD
`uptimed.conf` (`LOG_MAXIMUM_ENTRIES=0`): `gonf/goprecords/assets/uptimed.conf`.
Dotfiles installs the same upload script under `~/.local/bin` for the laptops.

Tokens: foostore `Infra/goprecords-token-<host>` (frontends, f-hosts) or file
fallback under `conf/gonf/secrets/` (see that tree’s README); laptops use
`~/.config/goprecords-upload-<host>/token`.

NetBSD Pis: binary is still the hand-built `/usr/pkg/sbin/uptimed` (no aarch64
pkgsrc package); gonf owns conf, `/etc/rc.d/uptimed`, and enable.

## API / keys (server)

- Report: `GET /report`
- Upload: `PUT /upload/{HOSTNAME}/{kind}` (`records`, `txt`, `cur.txt`, `os.txt`, `cpuinfo.txt`)
- Issue/replace a client key:

```sh
kubectl exec -n services deployment/goprecords -- \
  goprecords --create-client-key HOST -stats-dir=/data/stats
```

`HOSTNAME` must match `GOPRECORDS_HOST` / `--create-client-key` (short names:
`f0`, `pi2`, `zen`, …).

More API detail: goprecords repo **`README.md`**. Helm: **`conf/f3s/goprecords/`**.

## Ops notes not owned by gonf

### Rocky Pi clock sync (pi2/pi3)

Gonf installs
`/etc/systemd/system/uptimed.service.d/time-sync.conf` with
`ExecStartPre=/usr/bin/chronyc waitsync 60 0.5` so uptimed does not record a
stale boot time. See also [pihole-pi.md](../raspberry-pi/pihole-pi.md).

### Mac → mega-m3-pro via earth

Not a direct client. Worktime fish helpers
(`worktime::uprecords::darwin::{collect,import}`) sync Mac records into git;
earth’s `goprecords-upload-earth.service` (second `ExecStart`, soft-fail)
publishes them as **`mega-m3-pro`**. Dedicated token:
`~/.config/goprecords-upload-mega-m3-pro/token`.

### One-shot upload test

```sh
# earth / zen (user)
systemctl --user start goprecords-upload-earth.service   # or -zen
# f-hosts / NetBSD Pis / frontends (root script)
doas env GOPRECORDS_HOST=f0 /usr/local/bin/goprecords-upload-client.sh
# Rocky Pis
sudo systemctl start goprecords-upload.service
```

SSH to Beelinks/Pis is **port 22** (not the OpenBSD frontend port 2). Prefer
`fN.lan.buetow.org` / `piN.lan.buetow.org` or LAN IPs from the f3s host table.
