# NetBSD services on pi0/pi1

`pi0` and `pi1` run NetBSD 10.1 (evbarm-aarch64). This documents how their
services are installed and configured — useful reference for troubleshooting,
rebuilding a service, or reinstalling either node.

**Do this one node at a time.** Never take down both of `pi0`/`pi1` (the
static-HTTP pair) simultaneously — one must always keep serving
`f3s.buetow.org`/`snonux.foo`.

## Base state

- NetBSD 10.1 `GENERIC64` evbarm64 (aarch64)
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
export PKG_PATH=https://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/aarch64/10.1/All/
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
non-interactive shell an SSH command runs in — so
`~/git/dotfiles/scripts/wol-f3s`'s `shutdown-pis`/`shutdown-all` (which runs
`ssh paul@pi "doas poweroff"`) is silently broken on the Rocky Pis today. A
real `doas` binary is why it works on `pi0`/`pi1`.

**Gotcha**: commands run via `doas` get a minimal `PATH` that excludes
`/usr/sbin` and `/usr/pkg/bin` — always use full paths (`doas
/usr/sbin/chown`, `doas /usr/pkg/bin/wg`) or an explicit `PATH=` for cron.

## WireGuard (userspace — no native `wg(4)` on this platform)

**`wg(4)` doesn't exist on evbarm-aarch64 10.1** — the module is absent from
all 249 files under `/stand/evbarm/10.1/modules`, so `ifconfig wg0 create`
fails outright (`clone_command: Invalid argument`), despite `wg(4)` being
upstream NetBSD since 9.2. Don't waste time on it; `wireguard-go` + `wg`
(pkgsrc `wireguard-tools`, **no `wg-quick`** in this build) is the working
path:

```sh
pkgin -y install wireguard-go wireguard-tools
```

Pull this host's private key and the three PSKs (`blowfish`, `fishfinger`,
`rocky`) from `~/git/wireguardmeshgenerator/keys/` — do not regenerate.
Peer pubkeys/endpoints/AllowedIPs come from `dist/<host>/etc/wireguard/wg0.conf`
(generator output) or another live node's `/etc/wireguard/wg0.conf` (same
endpoints for every Pi, only `AllowedIPs`/PSK differ per host).

Key facts:

- The interface **must** be named `tunN` (`wireguard-go` rejects `wg0`:
  "Interface name must be tun[0-9]*"). Use `tun0`.
- **Address the interface before starting `wireguard-go`**, or its read loop
  dies immediately with `EHOSTDOWN` ("host is down") and does not retry:
  ```sh
  ifconfig tun0 create
  ifconfig tun0 inet <wg-ip> <wg-ip> netmask 255.255.255.255
  ifconfig tun0 inet6 <wg-ipv6>
  ifconfig tun0 up
  wireguard-go tun0     # daemonizes on its own
  ```
- Apply crypto config with the real `wg` CLI (supports `PersistentKeepalive`,
  unlike the native `wgconfig` tool which has no keepalive flag at all):
  ```sh
  wg setconf tun0 /usr/pkg/etc/wireguard/tun0.conf
  ```
  `tun0.conf` is the normal `[Interface]`/`[Peer]` format — same content as
  what `wireguardmeshgenerator` renders to `dist/<host>/etc/wireguard/wg0.conf`,
  just handed to `wg` instead of `wg-quick`.
- **No `wg-quick` means no automatic routes.** Each peer's AllowedIPs needs an
  explicit host route via the local tun IP:
  ```sh
  route add -inet <peer-allowed-ip>/32 <local-tun4-ip> -iface
  route add -inet6 <peer-allowed-ipv6>/128 <local-tun6-ip> -iface
  ```

Wire all of this into a custom `/etc/rc.d/wireguard` (there's no stock rc.d
for this combination). Enable with `wireguard=YES` in `/etc/rc.conf`.

**Known gap**: `wireguardmeshgenerator.rb` only branches on
`os == 'Linux' | 'FreeBSD' | 'OpenBSD'` and always emits `wg-quick`-style
files; the generator's YAML still lists `pi0`/`pi1` as `os: Linux`. Until it
gains NetBSD support, both nodes' WireGuard configs are manually-maintained
exceptions that a future `--generate`/`--install` regen would clobber.

## Webserver — bozohttpd

Built into NetBSD base, no package or config file. No stock rc.d exists that
actually uses `httpd_flags` (the shipped `/etc/rc.d/httpd` computes
`command_args` itself and never references that variable) — write a
dedicated `/etc/rc.d/bozohttpd`:

```sh
command="/usr/libexec/httpd"
pidfile="/var/run/bozohttpd.pid"
command_args="-b -X -U _httpd -P ${pidfile} -v /var/www/html -V /var/www/html"
required_dirs="/var/www/html"
```

- `-v /var/www/html -V /var/www/html`: vhost directory = same tree as the
  default docroot. A `Host:` header matching a **literally-named**
  subdirectory (e.g. `snonux.foo/`) is served from there; anything unmatched
  falls back to the plain docroot via `-V`.
- `www.snonux.foo` needs to be a symlink to `snonux.foo` (bozohttpd matches
  the literal Host header as a directory name, not a regex like lighttpd's
  `$HTTP["host"] =~ "^(www\.)?snonux\.foo$"`).
- **`-X` (directory indexing) is required**, not optional: bare directories
  with no `index.html` (e.g. a photo gallery folder under `/fotos/`) 404
  without it.
- **Give every real routed hostname its own vhost entry, even the "default"
  one** — don't rely on `-V` fallback for anything actually reachable from
  the internet. `f3s.buetow.org` (checked in `relayd.conf` on the frontends:
  the real routed names are `f3s.buetow.org`, `www.f3s.buetow.org`,
  `standby.f3s.buetow.org` — `/scifi/` etc. are **paths** under it, not
  separate subdomains) needs a vhost dir, or it hits `-V`, and bozohttpd's
  directory-without-trailing-slash redirect in that fallback path uses its
  own **system hostname**, not the client's `Host:` header (unlike a real
  vhost match, which correctly echoes back e.g. `snonux.foo`). Since the
  system hostname (`piN.lan.buetow.org`) doesn't resolve outside the LAN,
  this produces redirects that hang for external clients. Fix:
  self-referencing symlinks so these become vhost matches instead of
  fallbacks — `ln -sf . /var/www/html/f3s.buetow.org` (and the
  `www.`/`standby.` variants).

Enable with `bozohttpd=YES` in `/etc/rc.conf`.

## Static content sync

`pi0` is the source of truth for `/var/www/html`; `pi1` pulls hourly:

```sh
#!/bin/sh
set -e
STAGE=/tmp/wwwsync-cron
mkdir -p "$STAGE"
rsync -a --delete -e "ssh -o StrictHostKeyChecking=accept-new" \
	paul@pi0.lan.buetow.org:/var/www/html/ "$STAGE/"
doas rsync -a --delete --exclude=snonux.foo "$STAGE/" /var/www/html/
doas rsync -a --delete "$STAGE/snonux.foo/" /var/www/html/snonux.foo/
doas /usr/sbin/chown -R root:wheel /var/www/html/index.html /var/www/html/fotos /var/www/html/scifi
# snonux.foo is owned by paul, not root: the snonux microblog tool rsyncs
# directly into it as paul (no doas hop), so it must stay paul-writable.
doas /usr/sbin/chown -R paul:wheel /var/www/html/snonux.foo
```

Needs an SSH keypair for `paul` on `pi1`, authorized on `pi0`'s
`~/.ssh/authorized_keys`, plus a static `/etc/hosts` entry for `pi0` (Pi-to-Pi
`.lan.buetow.org` resolution isn't reliable — add the IP directly rather
than debugging DNS).

Install as `paul`'s crontab on `pi1` (not root's — needs the SSH key):
`47 * * * * /usr/local/bin/sync-from-pi0.sh >$HOME/sync-from-pi0.log 2>&1`

## uptimed (built from source — no prebuilt package)

**No aarch64 binary package exists** in pkgsrc for `uptimed` on any branch
checked (10.0, 10.1, 11.0, 9.4). Build from upstream instead — small C
project, NetBSD base already has `gcc`/`make`:

```sh
pkgin -y install autoconf automake libtool pkg-config
cd /tmp
curl -sLO https://github.com/rpodgorny/uptimed/archive/refs/tags/v0.4.7.tar.gz
tar xzf v0.4.7.tar.gz && cd uptimed-0.4.7
PATH=/usr/pkg/bin:$PATH ./autogen.sh
PATH=/usr/pkg/bin:$PATH ./configure --prefix=/usr/pkg --sysconfdir=/etc
PATH=/usr/pkg/bin:$PATH make
doas env PATH=/usr/pkg/bin:/usr/bin:/bin:/usr/sbin:/sbin make install
```

Installs `uptimed` to `/usr/pkg/sbin`, `uprecords` to `/usr/pkg/bin`, and uses
`/var/spool/uptimed/records` (hardcoded upstream, not an OS convention thing).

**Before first start**, write `/etc/uptimed.conf` with `LOG_MAXIMUM_ENTRIES=0`
(keep forever) plus milestone lines. If restoring a backed-up uptime history,
seed **both** `records` and `records.old` with the same content:

```sh
doas cp <backed-up-records-file> /var/spool/uptimed/records
doas cp <backed-up-records-file> /var/spool/uptimed/records.old   # both, not just one
doas /usr/sbin/chown root:wheel /var/spool/uptimed/records /var/spool/uptimed/records.old
```

**Critical bug to know about**: `read_records()` in `libuptimed/urec.c`
unconditionally sets `useold = -1` ("no useable database found") if
`records.old` doesn't exist yet — **regardless of whether the primary
`records` file is valid**. Seeding only `records` and starting the daemon
loses the imported history immediately (it gets shunted to a fresh
`records.old` on the first periodic rewrite, then overwritten again 60s
later). Seed **both** files with the same content before the first start.

Write a custom `/etc/rc.d/uptimed` (upstream ships a Linux-init `etc/rc.uptimed`,
not usable directly):

```sh
command="/usr/pkg/sbin/uptimed"
pidfile="/var/run/uptimed.pid"
command_args="-p ${pidfile}"
```

Run `uptimed -b` once (creates the boot ID), enable with `uptimed=YES`.

## goprecords upload

```sh
kubectl exec -n services deployment/goprecords -- \
	goprecords --create-client-key <host> -stats-dir=/data/stats
```
(from a machine with cluster access — this can occasionally 502 if the
apiserver's exec proxy can't reach whichever k3s node the pod landed on; just
retry, it's a transient networking issue, not a token problem.)

Deploy `goprecords-upload-client.sh` (from `~/git/goprecords/scripts/`,
already POSIX/generic and already handles `/var/spool/uptimed/records` and a
NetBSD `dmesg.boot`/`sysctl` fallback for `os.txt`/`cpuinfo.txt` — no changes
needed) to **`/usr/pkg/bin/`** to match the pre-baked crontab's path, token at
`/etc/goprecords-upload.token` (`0600`), `GOPRECORDS_HOST=<host>`.

`curl` and `uprecords` need to be resolvable via whatever `PATH` the cron
entry sets — test with that exact `PATH` before trusting a manual test run
under plain `doas` (which won't have it).

## Firewall — npf, not firewalld

```
$ext_if = "mue0"

group "external" on $ext_if {
	pass stateful out final all
	pass stateful in final family inet4 proto tcp to $ext_if port 22
	pass stateful in final family inet4 proto tcp to $ext_if port 80
	pass stateful in final family inet4 proto icmp all
}

group "wireguard" on tun0 {
	pass stateful out final all
	pass stateful in final family inet4 all
	pass stateful in final family inet6 all
}

group default {
	pass final on lo0 all
	block all
}
```

`family inet4`/`inet6` must be explicit on multi-family interfaces or
`npfctl validate` fails with "address family mismatch". `proto <name>` must
be followed by `all` or a `from`/`to` clause, or it's a syntax error — e.g.
`proto icmp` alone fails, `proto icmp all` doesn't. Don't forget the ICMP
rule: without it, ping-dependent tooling (e.g. the `snonux` publishing
tool's reachability pre-check) silently breaks while SSH/HTTP keep working
fine.

Sequence carefully to avoid locking yourself out over SSH:

```sh
doas npfctl validate           # syntax-check first
doas npfctl reload             # loads config, does NOT enable filtering yet
doas npfctl start               # enables filtering
# from a FRESH ssh connection (not the one you're already in), confirm:
#   - ssh still connects
#   - curl http://localhost/ still works
doas sh -c 'echo npf=YES >> /etc/rc.conf'   # only after confirming the above
```

If you get a JIT warning (`error loading the bpfjit module... Operation not
permitted`) — harmless, just means `kern.securelevel` blocks loading that
optional performance module; filtering still works, just slightly slower
packet matching.

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
- `wol-f3s shutdown-pis` (or a targeted `ssh paul@<host> "doas poweroff"`)
  actually powers the Pi off — confirms `doas` works non-interactively, but
  there's no WoL for Pis, so only do this when you can physically power it
  back on.
