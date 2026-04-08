# Garage

Garage S3 runs as a 3-node cluster on FreeBSD hosts `f0`, `f1`, and `f2`.

## Topology

- Nodes: `f0.lan.buetow.org`, `f1.lan.buetow.org`, `f2.lan.buetow.org`
- RPC: `:3901`
- S3 API: `:3900`
- Admin/metrics: `:3903`
- Layout capacity target: `f0=8`, `f1=8`, `f2=4` (same ratio currently applied)
- Zone: currently all in `dc1`
- Garage version: `2.2.0` (cargo build)

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

- Use `ssh -p 22` for `f0/f1/f2` when running ad-hoc commands; default SSH config for `*.buetow.org` may route to a different port and fail for these hosts.
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
