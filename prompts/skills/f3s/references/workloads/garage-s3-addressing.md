# Garage: S3 addressing modes and per-bucket hostnames

## S3 addressing modes (read this before wiring up a client)

Garage serves S3 two ways, and clients do not always choose consciously:

- **Path-style** — `https://endpoint/<bucket>/<key>`. Always works.
- **Virtual-hosted style** — `https://<bucket>.<endpoint>/<key>`. Works only
  because `root_domain = ".garage.f3s.buetow.org"` is set in `garage.toml.tmpl`,
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

In conf `gonf/frontends/data.go`:

```go
var garageBuckets = []string{"taskwarrior", "quicklog"}
```

Each bucket becomes `<bucket>.garage.f3s.buetow.org` and is appended to the
f3s host list (and from there to the ACME certificate list), so one entry
generates all of:

- A/AAAA records for the host plus `www.` and `standby.` variants, each marked
  `; Enable failover` with TTL 300 — so `dns-failover.ksh` swaps them like any
  other host
- a Let's Encrypt certificate, plus a separate `standby.` certificate
- `tls keypair` lines in `relayd.conf`
- httpd port-80 blocks for the ACME challenge

Only the routing differs, and it is matched by suffix in
`gonf/frontends/data.go` so new buckets need no routing edit:

```go
if name == "garage.f3s.buetow.org" || strings.HasSuffix(name, ".garage.f3s.buetow.org") {
        site.RelaydUpstream = "garage"
```

Then, from the conf repo:
`./gonf.sh cluster frontends frontends_nsd frontends_httpd frontends_acme frontends_acme_invoke frontends_relayd`.

**Order matters.** `acme.sh` skips a host that is not yet in `/etc/httpd.conf`
(and installs a foo.zone placeholder certificate instead), so `frontends_httpd`
must run **before** `frontends_acme_invoke` (keep the task order above). A placeholder shows up as a cert whose subject is
`CN=foo.zone` on the new name.

**There is no wildcard option.** `acme-client` implements only the `http-01`
challenge and Let's Encrypt issues wildcards solely via `dns-01`, so
`*.garage.f3s.buetow.org` cannot be certified without replacing the ACME client.
Per-bucket certificates are the mechanism.
