# NetBSD services on pi0/pi1

`pi0` and `pi1` run NetBSD 11.0 (evbarm-aarch64). This documents how their
services are installed and configured — useful reference for troubleshooting,
rebuilding a service, or reinstalling either node.

**Do this one node at a time.** Never take down both of `pi0`/`pi1` (the
static-HTTP pair) simultaneously — one must always keep serving
`f3s.buetow.org`/`snonux.foo`.

## Base state

- NetBSD 11.0 `GENERIC64` evbarm64 (aarch64)
- User `paul`, in group `wheel`, SSH key auth
- Static LAN IP via `rc.conf` (`ifconfig_mue0="inet 192.168.1.12N netmask
  0xffffff00"`, `defaultroute="192.168.1.1"`)
- Hostname set (`hostname="piN.lan.buetow.org"`)
- No `doas`/`sudo`, no pkgsrc/pkgin by default — bootstrapped below
- A pre-baked root crontab entry for the hourly goprecords upload already
  points at `/usr/pkg/bin/goprecords-upload-client.sh` with `GOPRECORDS_HOST`
  set correctly — check `doas crontab -l` before deploying that script
  manually to a different path.

## Bootstrap pkgin + real doas

```sh
ssh paul@piN.lan.buetow.org
su -
export PKG_PATH=https://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/aarch64/11.0/All/
pkg_add -v pkgin
pkgin -y update
pkgin -y install doas rsync curl
printf 'permit nopass :wheel\n' > /usr/pkg/etc/doas.conf   # NOT "permit persist" --
                                                             # that still prompts once
                                                             # per session, which never
                                                             # succeeds over a
                                                             # non-interactive SSH
                                                             # command (no tty)
chmod 644 /usr/pkg/etc/doas.conf
exit   # back to paul
doas true   # should succeed with no password prompt
```

**Why real `doas`, not the Rocky pattern**: `pi2`–`pi3` only alias `doas` to
`sudo` via `/etc/profile.d/doas.sh`, which doesn't expand in the
non-interactive shell an SSH command runs in — so any remote
`ssh paul@pi "doas <cmd>"` silently resolves to nothing on the Rocky Pis. A
real `doas` binary is why the same call works on `pi0`/`pi1`. `f3sctl` depends
on this: its CGI runs as `_httpd` and reaches the f-hosts with an explicit
`-i` identity, but operator commands on the Pis assume `doas` works
non-interactively.

**Gotcha**: commands run via `doas` get a minimal `PATH` that excludes
`/usr/sbin` and `/usr/pkg/bin` — always use full paths (`doas
/usr/sbin/chown`, `doas /usr/pkg/bin/wg`) or an explicit `PATH=` for cron.

## Major-version upgrade recovery lessons

- Run the sets installation and its conditional orderly reboot together in one
  HUP-resistant root shell, for example:
  `doas sh -c 'trap "" HUP; /usr/pkg/sbin/sysupgrade sets </dev/null >/var/log/sysupgrade-sets.log 2>&1 && exec /sbin/shutdown -r now'`.
  Do not depend on opening another SSH session after replacing userland.
- After `etcupdate`, verify the active account databases, then prove a fresh
  SSH key login and `doas` from a new session before releasing the existing
  privileged session.

## Verification

- `curl -fsI http://<host>.lan.buetow.org/` and the vhost via `Host:` header.
- `wg show tun0` shows recent handshakes with `blowfish` and `fishfinger` (and
  `rocky` if that VM happens to be up — it's often not, unrelated to this).
- goprecords report (`https://goprecords.f3s.buetow.org/report`) picks up the
  host after the hourly cron fires (won't rank in the "top 20 all-time" table
  with a short history — that's expected, not a failure).
- **Redundancy test**: stop the *other* node's webserver entirely, then curl
  every real page through the **public** domains (not just localhost) — root
  page, each vhost, and any bare directory paths (e.g. `/fotos/`). Restore
  the other node's webserver immediately after.
- `ssh paul@<host> "doas poweroff"` actually powers the Pi off — confirms
  `doas` works non-interactively, but there's no WoL for Pis, so only do this
  when you can physically power it back on. `f3sctl` deliberately offers no
  route for this: pi0/pi1 host the power API, so powering them off would
  remove the only way to power anything back on.
