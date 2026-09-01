# Garage

Garage S3 runs as a 3-node cluster on FreeBSD hosts `f0`, `f1`, and `f2`.

## Topology

- Nodes: `f0.lan.buetow.org`, `f1.lan.buetow.org`, `f2.lan.buetow.org`
- RPC: `:3901`
- S3 API: `:3900`
- Admin/metrics: `:3903`
- Layout capacity target: `f0=8`, `f1=8`, `f2=4` (same ratio currently applied)
- Zone: currently all in `dc1`
- Garage version: `cargo:2.3.0`
- `replication_factor = 3`, `consistency_mode = "consistent"`, S3 region `garage`
- `root_domain = ".garage.f3s.buetow.org"` — enables virtual-hosted-style
  addressing, see "S3 addressing modes" below
- Endpoints: `https://garage.f3s.buetow.org` (public, via relayd) or
  `http://192.168.1.130:3900` (LAN direct, also `.131` / `.132`)

## Local Data and Service Setup

- Encrypted ZFS datasets created per host:
  - `zroot/garage/meta` mounted at `/var/db/garage/meta`
  - `zroot/garage/data` mounted at `/var/db/garage/data`
- Service enabled:
  - `garage_enable=YES` in `/etc/rc.conf`
- Config deployed by repo automation in `f3s/garage/`:
  - `f3s/garage/Rexfile`
  - `f3s/garage/Justfile`
  - `f3s/garage/etc/garage.f0.toml`
  - `f3s/garage/etc/garage.f1.toml`
  - `f3s/garage/etc/garage.f2.toml`
- Shared RPC secret is read from:
  - `f3s/garage/secrets/rpc_secret` (intentionally gitignored)

## Edge Domain and Frontend Routing

- Public hostname: `garage.f3s.buetow.org`
- Frontend wiring exists:
  - Domain included in `frontends/Rexfile` f3s host list
  - `relayd` backend table and host match added in `frontends/etc/relayd.conf.tpl`
  - TLS certificate for `garage.f3s.buetow.org` is issued and served
- Current routing health:
  - DNS resolves on public edge hosts (`A` + `AAAA`)
  - HTTPS returns expected S3 XML error for anonymous requests (`403 AccessDenied`)
  - Authenticated S3 operations via external hostname are working

## S3 addressing modes (read this before wiring up a client)

Garage serves S3 two ways, and clients do not always choose consciously:

- **Path-style** — `https://endpoint/<bucket>/<key>`. Always works.
- **Virtual-hosted style** — `https://<bucket>.<endpoint>/<key>`. Works only
  because `root_domain = ".garage.f3s.buetow.org"` is set in `garage.fN.toml`,
  which lets Garage map the Host header back to a bucket.

The AWS SDKs derive the hostname as `<bucket>.<endpoint-host>` by default, and
fall back to path-style **only when the endpoint is an IP literal** — a bucket
name cannot be prefixed onto an IP. Consequences:

| Endpoint | Mode | What it needs |
|---|---|---|
| `http://192.168.1.130:3900` | path-style, automatic | nothing; LAN only |
| `https://garage.f3s.buetow.org` | virtual-hosted | `<bucket>.garage.f3s.buetow.org` must resolve, be certified and be routed |

Both modes work side by side. Enabling `root_domain` did **not** disturb
existing path-style consumers — verified by checking that requests still arrive
as `GET /<bucket>/...` with the bucket in the path.

Some clients can force path-style over a hostname endpoint; many cannot. AWS's
own `AWS_ENDPOINT_URL_S3` / `AWS_ENDPOINT_URL` environment variables override
the endpoint for any SDK-based client, but there is **no** environment variable
for path-style — that is a client-side build option only. `~/.aws/config` is not
consulted for the endpoint by every SDK either: the Rust SDK ignores both a
profile `endpoint_url` and the documented `[services]` form.

## Giving a bucket its own hostname

Needed whenever a client uses virtual-hosted addressing. Bucket hostnames are
ordinary f3s hosts, one level deeper, so they reuse the existing machinery
rather than a special case.

In `conf:frontends/Rexfile`:

```perl
our @garage_buckets = qw/taskwarrior/;
our @garage_hosts   = map { "$_.garage.f3s.buetow.org" } @garage_buckets;
push @f3s_hosts, @garage_hosts;
```

Because they land in `@f3s_hosts` (and from there in `@acme_hosts`), one entry
generates all of:

- A/AAAA records for the host plus `www.` and `standby.` variants, each marked
  `; Enable failover` with TTL 300 — so `dns-failover.ksh` swaps them like any
  other host
- a Let's Encrypt certificate, plus a separate `standby.` certificate
- `tls keypair` lines in `relayd.conf`
- httpd port-80 blocks for the ACME challenge

Only the routing differs, and it is matched by suffix in
`frontends/etc/relayd.conf.tpl` so new buckets need no edit there:

```perl
} elsif ($host eq 'garage.f3s.buetow.org'
      or $host =~ /\.garage\.f3s\.buetow\.org$/) {
```

Then: `cd conf/frontends && rex nsd httpd acme acme_invoke relayd`.

**Order matters.** `acme.sh` skips a host that is not yet in `/etc/httpd.conf`
(and installs a foo.zone placeholder certificate instead), so `httpd` must run
**before** `acme_invoke`. A placeholder shows up as a cert whose subject is
`CN=foo.zone` on the new name.

**There is no wildcard option.** `acme-client` implements only the `http-01`
challenge and Let's Encrypt issues wildcards solely via `dns-01`, so
`*.garage.f3s.buetow.org` cannot be certified without replacing the ACME client.
Per-bucket certificates are the mechanism.

## Critical Fix Applied

The key issue was that Garage S3/admin listeners were IPv6-only in TOML:

- old: `api_bind_addr = "[::]:3900"` and `"[::]:3903"`
- fixed: `api_bind_addr = "0.0.0.0:3900"` and `"0.0.0.0:3903"` on `f0/f1/f2`

After redeploy, `fishfinger` and `blowfish` can reach all Garage nodes on WireGuard IPv4:

- `192.168.2.130:3900`
- `192.168.2.131:3900`
- `192.168.2.132:3900`

This resolved the external edge path instability.

## Existing Buckets / Keys

- First bucket: `watchos-app`
- First access key alias: `watchos-key`
- Bucket permission: read/write granted to `watchos-key`
- Authenticated external endpoint test is validated (PUT + LIST via `https://garage.f3s.buetow.org`)
- Do not store key secrets in git; rotate if exposed in logs.

## Prometheus

- Scrape config for Garage admin endpoints was added under:
  - `f3s/prometheus/additional-scrape-configs.yaml`
  - `f3s/prometheus/manifests/additional-scrape-configs-secret.yaml`
- Current state observed: targets present but `down` with `connection refused` on `:3903`.

## Operational Notes (Important)

- SSH to `f0/f1/f2` is on **port 22**. `~/.ssh/config` now carries an explicit
  `Host f0.lan.buetow.org f1.lan.buetow.org f2.lan.buetow.org f3.lan.buetow.org`
  block with `Port 22`, which must stay **above** the `Host *.buetow.org`
  catch-all (`Port 2`, correct for the OpenBSD frontends) because ssh applies
  the first matching block.
- `garage_deploy` scopes its login with `auth for => 'garage_nodes'` rather than
  a bare `user 'paul'`, and that must stay scoped. The top-level `conf/Rexfile`
  requires **every** sub-Rexfile and `user()` is a *global* setting, so the file
  loaded last wins: `f3s/r-nodes/Rexfile` sets `user 'root'` and is required
  after the garage one. With a global setting the deploy silently attempted to
  log in as `root`, which these hosts refuse, and failed on all three nodes with
  a misleading "Couldn't authenticate" error. The same trap applies to `port()`
  and `sudo()`.
- Garage 2.2 `node connect` expects `nodeid@host:port` format (not only `host:port`).
- Ensure `/var/db/garage/meta` and `/var/db/garage/data` ownership allows Garage process access (`garage:garage`).
- `garage.toml` is installed as `root:garage` mode `640` so service user can read it.
- `f3s/garage/secrets/rpc_secret` must exist locally before deploy; keep it out of git.

## Recovery Checklist (Public Endpoint Issues)

When `https://garage.f3s.buetow.org` is broken, use this order:

1. Confirm cluster health first (avoid debugging edge when backend is down):
   - `ssh -p 22 paul@f0.lan.buetow.org 'doas garage status'`
   - `ssh -p 22 paul@f0.lan.buetow.org 'doas garage stats -a'`
2. Confirm Garage listeners are on IPv4 on all nodes:
   - `ssh -p 22 paul@fN.lan.buetow.org 'sockstat -4 -l | grep 3900'`
   - Expected: `*:3900` (and similarly `*:3903` for admin)
3. Confirm edge hosts can reach WireGuard backends:
   - from `fishfinger` and `blowfish`: `nc -zvw2 192.168.2.13{0,1,2} 3900`
4. Confirm relayd syntax and reload state:
   - `ssh rex@fishfinger.buetow.org 'doas relayd -n'`
   - `ssh rex@blowfish.buetow.org 'doas relayd -n'`
5. Confirm public DNS and TLS:
   - `host garage.f3s.buetow.org`
   - `curl -v https://garage.f3s.buetow.org/` (expect XML `403 AccessDenied` for anonymous)
6. Run authenticated S3 external test:
   - execute the authenticated PUT/LIST command from this document
7. If listeners are wrong or config drifted:
   - fix TOML in `f3s/garage/etc/garage.fN.toml`
   - redeploy: `just -f f3s/garage/Justfile deploy`
8. If relay changes were made:
   - redeploy frontends from `frontends/` (`rex nsd httpd relayd`) and rerun ACME flow if keypair errors appear.

## Useful Commands

### Cluster health

```sh
ssh -p 22 paul@f0.lan.buetow.org 'doas garage status'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage stats -a'
```

### Local S3 check (no public endpoint)

```sh
ssh -p 22 paul@f0.lan.buetow.org 'curl -sS -o /dev/null -w "%{http_code}\n" http://localhost:3900/'
```

### External endpoint checks

```sh
# Anonymous check should return 403 AccessDenied XML (expected)
ssh rex@fishfinger.buetow.org 'curl -sS -D - https://garage.f3s.buetow.org/ | sed -n "1,20p"'

# Reachability from edge hosts to Garage WG backends
ssh rex@fishfinger.buetow.org 'for ip in 192.168.2.130 192.168.2.131 192.168.2.132; do nc -zvw2 $ip 3900; done'
ssh rex@blowfish.buetow.org 'for ip in 192.168.2.130 192.168.2.131 192.168.2.132; do nc -zvw2 $ip 3900; done'
```

### Bucket aliases

A bucket can answer to more than one global name, which matters because with
virtual-hosted addressing the bucket name *is* part of the DNS name:

```sh
doas garage bucket alias   <existing-bucket> <new-name>
doas garage bucket unalias <name>
```

Renaming is therefore add-alias-then-remove-old, with no data movement.

### Bucket and key workflow

```sh
ssh -p 22 paul@f0.lan.buetow.org 'doas garage bucket create <bucket>'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage key create <key-alias>'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage bucket allow <bucket> --read --write --key <key-alias>'
ssh -p 22 paul@f0.lan.buetow.org 'doas garage key info <key-alias>'
```

### Authenticated S3 test via external hostname

```sh
ssh -p 22 paul@f0.lan.buetow.org '
TMP=$(mktemp)
doas garage key info watchos-key --show-secret > "$TMP"
AK=$(awk -F": " "/Key ID:/ {print \$2}" "$TMP" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
SK=$(awk -F": " "/Secret key:/ {print \$2}" "$TMP" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//")
OBJ="e2e-external-$(date +%s).txt"
echo "ok" >/tmp/$OBJ
AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION=garage \
  aws --endpoint-url https://garage.f3s.buetow.org s3 cp /tmp/$OBJ s3://watchos-app/$OBJ
AWS_ACCESS_KEY_ID="$AK" AWS_SECRET_ACCESS_KEY="$SK" AWS_DEFAULT_REGION=garage \
  aws --endpoint-url https://garage.f3s.buetow.org s3 ls s3://watchos-app/$OBJ
rm -f "$TMP" /tmp/$OBJ
'
```

## Known clients

### watchos-app

The original bucket, key alias `watchos-key`, path-style access.

### Taskwarrior sync

Bucket `taskwarrior`, key `taskwarrior-sync`, reached virtual-hosted as
`taskwarrior.garage.f3s.buetow.org`. This is what motivated `root_domain`:
Fedora's stock `task` 3.4.2 has **no** `sync.aws.endpoint_url` or
`sync.aws.force_path_style` key (both landed upstream after v3.5.0), so it
cannot be told to use path-style, and the endpoint has to come from the AWS
SDK's own environment variable.

Credentials and the client-side encryption secret live in
`~/.config/garage/taskwarrior-sync.env` (mode 0600). `~/.taskrc` refers to them
as `$GARAGE_*` / `$TASK_SYNC_SECRET` — taskrc expands environment variables, so
no secret sits in the config file.

```sh
tasksync                      # fish function, dotfiles/fish/conf.d/tasksync.fish
```

or by hand:

```sh
. ~/.config/garage/taskwarrior-sync.env
AWS_ENDPOINT_URL_S3="$GARAGE_ENDPOINT" task sync
```

`AWS_ENDPOINT_URL_S3` must be set **per-invocation, never exported**: a global
value redirects every SDK-based S3 client on the machine at Garage, and
`~/.aws` holds a live `[default]` profile.

Note the objects are opaque to Garage — TaskChampion encrypts client-side, so a
version object fetched straight from the bucket contains no readable task text.

Full background: `conf:f3s/docs/taskwarrior-s3-sync.md`.
