# Garage

Garage S3 runs as a 3-node cluster on FreeBSD hosts `f0`, `f1`, and `f2`.

## Topology

- Nodes: `f0.lan.buetow.org`, `f1.lan.buetow.org`, `f2.lan.buetow.org`
- RPC: `:3901`
- S3 API: `:3900`
- Admin/metrics: `:3903`
- Layout capacity target: `f0=8`, `f1=8`, `f2=4` (same ratio currently applied)
- Zone: currently all in `dc1`
- Garage version: `cargo:2.4.1` (native inspection 2026-10-23)
- `replication_factor = 3`, `consistency_mode = "consistent"`, S3 region `garage`
- `root_domain = ".garage.f3s.buetow.org"` — enables virtual-hosted-style
  addressing, see [garage-s3-addressing.md](garage-s3-addressing.md)
- Endpoints: `https://garage.f3s.buetow.org` (public, via relayd) or
  `http://192.168.1.130:3900` (LAN direct, also `.131` / `.132`)

## Local Data and Service Setup

- Encrypted ZFS datasets created per host:
  - `zroot/garage/meta` mounted at `/var/db/garage/meta`
  - `zroot/garage/data` mounted at `/var/db/garage/data`
- Service enabled:
  - `garage_enable=YES` in `/etc/rc.conf`
- Config deployed by the gonf task `garage_config` (cluster `garage` = f0–f2,
  `paul@…:22` + doas; deploy one node and verify health before the next):
  - `gonf/garage/garage.go` (the recipe)
  - `f3s/garage/etc/garage.toml.tmpl` (one template for all three nodes;
    per-node `rpc_public_addr` comes from the inventory)
  - `f3s/garage/Justfile` uses
    `just -f f3s/garage/Justfile deploy f2` for one selected node; `f0` and `f1`
    are also accepted. Keep the cn3 credential/Prometheus prerequisites and
    serial health gates when using this deployment recipe.
  - Configuration only: the package, `garage` group, `/var/db/garage` and the
    cluster layout are provisioning steps outside gonf. Garage restarts only
    when the rendered config changed.
- Shared RPC secret is read from the foostore/KeePass vault entry
  `Infra/garage-rpc` (Password field), falling back to
  `gonf/secrets/garage/rpc_secret` (intentionally gitignored;
  `just -f f3s/garage/Justfile init-secrets` creates it) only when the vault
  has no such entry; see conf `gonf/secrets/README.md`.

## Edge Domain and Frontend Routing

- Public hostname: `garage.f3s.buetow.org`
- Frontend wiring exists:
  - Domain included in the `f3sHosts` list in conf `gonf/frontends/data.go`
  - `relayd` upstream `garage` selected in `gonf/frontends/data.go` and rendered by `gonf/frontends/assets/relayd.conf.tmpl`
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
- All three targets (`192.168.2.13{0,1,2}:3903/metrics`) are `up` (verified
  2026-10-20). The old `connection refused` came from the IPv6-only admin
  bind, fixed below.

## Gogios

- Each node has its own check, `Check Garage Health fN.wg0.wan.buetow.org`
  (task pm3, `addGarageChecks` in conf `gonf/frontends/monitoring.go`):
  `check_http -H 192.168.2.13N -p 3903 -u /health` over WireGuard.
- The public `garage.f3s.buetow.org` 403 check alone cannot see a dead node,
  because relayd forwards to whichever node passes its TCP check.
- `/health` needs no admin token. It returns 200 while the node has quorum
  (body `Garage is fully operational`, or a degraded message) and 503
  without quorum. The check does not match the body text, so one dead node
  alerts once rather than three times.
- Each check depends on `Check Ping4 fN.wg0.wan.buetow.org` and pauses while
  `/tmp/f3s_taken_down` exists. The node list is `garageNodes` in
  `gonf/frontends/data.go`; keep it in step with `cluster.NameGarage`.
- Deploy: `./gonf.sh cluster frontends frontends_gogios`.

## Admin/metrics hardening (cn3; deployed 2026-10-24)

The approved conf change binds admin/metrics to each node's WireGuard IP and
requires a dedicated metrics token from `Infra/garage-metrics` (Password field).
The existing RPC/S3 identity, addresses, local storage and layout are preserved.
The TOML remains 0640 root:garage and is marked secret-bearing. Prometheus gets
an external `monitoring/garage-metrics` Secret, key `token`, mounted at
`/etc/prometheus/secrets/garage-metrics/token`; public scrape configs contain
only that file reference. Production Garage 2.4.1 returns 403 for missing or
wrong metrics tokens; unauthenticated `/health` remains available for Gogios.

The dedicated vault entry and external Kubernetes Secret were provisioned
with approval; exact readback/reuse checks passed without displaying values.
`scripts/provision-metrics-secret.py` in conf's `f3s/garage` defaults to checking;
`--apply` creates only an absent Secret and refuses replacement. Provision and
verify it before publishing the Prometheus mount/config change. That rollout
restarts Prometheus; then deploy Garage one node at a time, checking all three
nodes/metrics/S3 after each. This sequence completed f2, f1, then f0, with
accepted rollback guards, unchanged RPC/storage/layout and native 0640
root:garage TOMLs. Fresh authenticated scrapes, actual Gogios health checks,
trusted S3 listing/object reads and zero-change reapplication passed.
`just deploy` requires one explicit f-host. Follow
`conf/f3s/garage/admin-metrics.md` for rollback and the acceptance record;
this section does not authorize future changes.

## Operational Notes (Important)

- SSH to `f0/f1/f2` is on **port 22**. `~/.ssh/config` now carries an explicit
  `Host f0.lan.buetow.org f1.lan.buetow.org f2.lan.buetow.org f3.lan.buetow.org`
  block with `Port 22`, which must stay **above** the `Host *.buetow.org`
  catch-all (`Port 2`, correct for the OpenBSD frontends) because ssh applies
  the first matching block.
- SSH user, port and privilege are set per host in `gonf/cluster/cluster.go`.
- Garage 2.2 `node connect` expects `nodeid@host:port` format (not only `host:port`).
- Ensure `/var/db/garage/meta` and `/var/db/garage/data` ownership allows Garage process access (`garage:garage`).
- `garage.toml` is installed as `root:garage` mode `640` so service user can read it.
- `gonf/secrets/garage/rpc_secret` must exist locally before deploy; keep it out of git.

## Recovery Checklist (Public Endpoint Issues)

When `https://garage.f3s.buetow.org` is broken, use this order:

1. Confirm cluster health first (avoid debugging edge when backend is down):
   - `ssh -p 22 paul@f0.lan.buetow.org 'doas garage status'`
   - `ssh -p 22 paul@f0.lan.buetow.org 'doas garage stats -a'`
2. Confirm Garage listeners are on IPv4 on all nodes:
   - `ssh -p 22 paul@fN.lan.buetow.org 'sockstat -4 -l | grep 3900'`
   - Expected S3: `*:3900`. Admin must use only that node's
     `192.168.2.13N:3903` WireGuard address; a wildcard admin listener is drift.
3. Confirm edge hosts can reach WireGuard backends:
   - from `fishfinger` and `blowfish`: `nc -zvw2 192.168.2.13{0,1,2} 3900`
4. Confirm relayd syntax and reload state:
   - `ssh rex@fishfinger.buetow.org 'doas relayd -n'`
   - `ssh rex@blowfish.buetow.org 'doas relayd -n'`
5. Confirm public DNS and TLS:
   - `host garage.f3s.buetow.org`
   - `curl -v https://garage.f3s.buetow.org/` (expect XML `403 AccessDenied` for anonymous)
6. Run authenticated S3 external test:
   - execute the authenticated PUT/LIST command from [garage-commands.md](garage-commands.md)
7. If listeners are wrong or config drifted:
   - fix the template `f3s/garage/etc/garage.toml.tmpl` (or the per-host inventory value in `gonf/cluster/cluster.go`)
   - after approval and the cn3 credential/Prometheus prerequisites, redeploy
     one selected node, for example `just -f f3s/garage/Justfile deploy f2`;
     verify health/quorum/S3/metrics before any other node
8. If relay changes were made:
   - redeploy the frontends from the conf repo (`./gonf.sh cluster frontends frontends_nsd frontends_httpd frontends_relayd`) and rerun the ACME flow (`frontends_acme frontends_acme_invoke`, then `frontends_relayd`) if keypair errors appear.
