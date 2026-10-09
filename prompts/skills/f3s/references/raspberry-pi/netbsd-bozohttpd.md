# NetBSD Pis: bozohttpd webserver and static content sync

## Webserver — bozohttpd

Built into NetBSD base, no package or config file. No stock rc.d exists that
actually uses `httpd_flags` (the shipped `/etc/rc.d/httpd` computes
`command_args` itself and never references that variable) — write a
dedicated `/etc/rc.d/bozohttpd`:

```sh
command="/usr/libexec/httpd"
pidfile="/var/run/bozohttpd.pid"
command_args="-b -X -U _httpd -c /usr/local/libexec/cgi-bin -P ${pidfile} -v /var/www/html -V /var/www/html"
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

### CGI (`-c`) — argument order matters

`-c /usr/local/libexec/cgi-bin` enables the CGI/1.1 interface; bozohttpd then
executes anything under that directory for URLs beginning `/cgi-bin/`. It is
what serves `f3sctl` (the power API) on pi0/pi1.

**Do not leave backup copies of `/etc/rc.d/bozohttpd` in `/etc/rc.d/`.**
`rcorder` runs every executable there that `PROVIDE`s a service. Leftovers
named `bozohttpd.pre-cgi` / `bozohttpd.bak` (same `PROVIDE: bozohttpd`, same
`rcvar`, no `-c`) sort *before* the real script and start httpd without CGI.
A later `/etc/rc.d/bozohttpd start` then sees the pidfile and is a no-op — so
`/cgi-bin/f3sctl` 404s until someone restarts the real script. Observed
2026-09-08 after a dual-Pi reboot: both nodes came up on the pre-cgi argv.
Keep backups under `/root/rc.d-bak/` (or anywhere outside `/etc/rc.d/`).

**The `-c` flag must come before the trailing `/var/www/html`.** bozohttpd's
usage is `httpd [options] slashdir [myname]`, and **`-V` takes no argument** —
it is a bare flag meaning "fall back to slashdir". So the last `/var/www/html`
on that line is the positional *slashdir*, not an argument to `-V`. `getopt`
stops at the first non-option, so an option appended after it is parsed as
extra positional junk and bozohttpd exits with a usage error. From rc.d this
looks like a silent failure: `Starting bozohttpd.` is printed, nothing listens,
and `/var/log/messages` says nothing. (Learned the hard way — 2026-08-08.)

The cgibin directory is deliberately **outside** `/var/www/html`: the hourly
pi0→pi1 content rsync never touches the binaries, and they can never show up in
a `-X` directory index.

Verified CGI environment on NetBSD 11.0 (`bozohttpd/20260508`):

- **arbitrary request headers are exported** as `HTTP_<UPPERCASED_NAME>` —
  `X-API-Key` arrives as `HTTP_X_API_KEY`. This is what makes header-based API
  keys viable instead of putting them in the query string.
- `PATH_INFO` works: `/cgi-bin/f3sctl/power/off` gives `SCRIPT_NAME=/cgi-bin/f3sctl`
  and `PATH_INFO=/power/off`, so one binary can route its own sub-paths.
- `QUERY_STRING`, `REQUEST_METHOD`, `CONTENT_TYPE`/`CONTENT_LENGTH` and the
  POST body on stdin all behave normally.
- `GATEWAY_INTERFACE=CGI/1.1` is set, which is how `f3sctl` detects CGI mode.
- `SERVER_NAME` echoes the client's `Host:`, but `PWD` stays `/var/www/html`
  regardless of vhost — do not infer the vhost from the working directory.
- The environment is otherwise cleared (because of `-U _httpd`, unless `-e` is
  given), and `PATH` is `/usr/bin:/bin:/usr/pkg/bin:/usr/local/bin`.

**That `PATH` has no `/sbin`**, which is where NetBSD keeps `ping`, `chown`,
`ifconfig` and friends. A CGI that shells out to one of them must use an
absolute path. This bit `f3sctl`: its ICMP probe called `ping` by name, found
nothing, and reported every host as `ping=false` while they were plainly
answering on port 22 — which then withheld the `power-off` action entirely.
The same applies to `doas` invocations from a script (`doas chown` fails with
"command not found"; `doas /sbin/chown` works).

`/sbin/ping` is `-r-sr-xr-x root:wheel`, i.e. setuid root, and **works when run
as `_httpd`** — so a CGI gets real ICMP with no privilege grant and no raw
socket of its own. That is why the power API needs no `doas` rule at all.

## Static content sync

`pi0` is the source of truth for `/var/www/html`; `pi1` pulls hourly:

```sh
#!/bin/sh
set -e
STAGE=/tmp/wwwsync-cron
mkdir -p "$STAGE"
rsync -a --delete -e "ssh -o StrictHostKeyChecking=accept-new -o IdentitiesOnly=yes -i /home/paul/.ssh/id_ed25519" \
	paul@pi0.lan.buetow.org:/var/www/html/ "$STAGE/"
doas rsync -a --delete --exclude=snonux.foo "$STAGE/" /var/www/html/
doas rsync -a --delete "$STAGE/snonux.foo/" /var/www/html/snonux.foo/
doas /usr/sbin/chown -R root:wheel /var/www/html/index.html /var/www/html/fotos /var/www/html/scifi
# snonux.foo is owned by paul, not root: the snonux microblog tool rsyncs
# directly into it as paul (no doas hop), so it must stay paul-writable.
doas /usr/sbin/chown -R paul:wheel /var/www/html/snonux.foo
```

Needs an SSH keypair for `paul` on `pi1`, authorized on `pi0`'s
`~/.ssh/authorized_keys`. Keep unattended SSH pinned with
`IdentitiesOnly=yes` and the dedicated key; forwarded-agent identities can
otherwise exceed the server's authentication-attempt limit. Also add a static
`/etc/hosts` entry for pi0 (Pi-to-Pi `.lan.buetow.org` resolution is not
reliable — add the IP directly rather than debugging DNS).

Install as `paul`'s crontab on `pi1` (not root's — needs the SSH key):
`47 * * * * /usr/local/bin/sync-from-pi0.sh >$HOME/sync-from-pi0.log 2>&1`
