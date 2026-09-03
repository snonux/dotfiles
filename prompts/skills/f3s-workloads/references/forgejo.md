# Forgejo

Self-hosted git forge at `https://code.f3s.buetow.org`, running in the
`services` namespace. Config is in `f3s/forgejo/`. Backs 80+ repositories
(migrated from the legacy cgit `git-server`, which stays in `cicd` as a
read-only rollback — see `f3s/forgejo/README.md` for the full migration
history). ArgoCD itself reads `conf` from Forgejo
(`http://forgejo.services.svc.cluster.local/snonux/conf.git`), so Forgejo
being down blocks the whole GitOps pipeline, not just browsing.

## Architecture

```
Internet -> relayd (OpenBSD GW, TLS) -> WireGuard -> Traefik -> forgejo svc:80 -> pod:3000
git+ssh  -> NodePort 30222 -----------------------------------> pod:2222
```

SQLite (not Postgres) on NFS, single writer (`replicas: 1` + `Recreate`),
`SQLITE_JOURNAL_MODE=DELETE` because SQLite's default WAL mode doesn't work
over NFS. Rootless image, UID/GID 1000.

## Public Exposure and Crawler Traffic

**Incident (2026-08-19)**: a crawler systematically walked Forgejo's most
expensive pages — `/blame/`, `/commits/`, `/src/commit/`, `.patch` diffs —
across dozens of repositories, several requests/second, sustained for hours.
Because `code.f3s.buetow.org` is internet-facing through relayd/WireGuard,
this traffic rode the home fiber uplink itself (not just cluster CPU),
producing a 3-7.5 Mbps sustained floor that was mistaken for a general
"internet is slow" problem. Confirmed by:

- `kubectl -n services logs -l app=forgejo --tail=40` showing a dense run of
  `completed GET .../blame/...` / `.../commit/....patch` lines across many
  different repos in a few seconds — a real user doesn't browse like that.
- Prometheus `wg0` throughput (see
  [stack.md](../../f3s-observability/references/stack.md) "Diagnosing
  WAN-Saturating Cluster Traffic") showing a sustained multi-Mbps floor, not
  a single spike.
- NFS was ruled out separately: zero `retrans` in `nfsstat -c` on every
  r-node, and NFS traffic never leaves the LAN (`stunnel` to the CARP VIP
  over `127.0.0.1`) so it can't touch the WAN path regardless of volume.

**Fix — block the abused hostname on the standard port, keep a
non-standard port alive for legitimate/known access**, same idea as
git+ssh already living on `:2022` instead of `:22`:

- `frontends/etc/relayd.conf.tpl`: `block request header "Host" value
  "code.f3s.buetow.org"` (and the `www.`/`standby.` prefixes) inside the
  main `"https"` protocol — this drops the connection on `:443` before it
  ever reaches Traefik. Note `block quick` is **not** valid relayd syntax
  here (confirmed via `relayd -n`); plain `block` is correct and sufficient
  since these are the only rules matching that Host.
- A second protocol/relay pair (`"forgejo-alt"`, `forgejo_alt4`/`_alt6`)
  listens on `:2443` with the *same* TLS keypair and forwards only
  `code.f3s.buetow.org` through to `<f3s>` — so the web UI stays reachable
  at `https://code.f3s.buetow.org:2443/` without a hostname change.
- Port 80 is deliberately left alone: relayd never proxies `:80` to the
  cluster (httpd only does ACME-challenge/redirect there), and blocking it
  would break the cert renewal that the `:2443` listener depends on.
- git+ssh on `:2022` is untouched — that relay is a plain TCP forward with
  no Host-header awareness, so it was never part of the exposure.

Don't spell out the `:2443` port number in prose/docs beyond what's
functionally required in `relayd.conf.tpl` — this repo is itself served
publicly via Forgejo and mirrored on Codeberg, so anything written in clear
text here is exactly as crawlable as the pages that caused the incident.

**Verifying the fix** (from a machine with real DNS/internet egress, not
from inside the cluster):

```sh
curl -s -o /dev/null -w "%{http_code}\n" https://code.f3s.buetow.org/          # expect 000 (dropped)
curl -sk -o /dev/null -w "%{http_code}\n" https://code.f3s.buetow.org:2443/    # expect 200
```

Check both gateways explicitly with `--resolve code.f3s.buetow.org:<port>:<gateway-ip>`
since blowfish and fishfinger are deployed and restarted independently.

## Hostname/Ingress Drift

The public hostname is managed in three places that must agree: `@f3s_hosts`
in `frontends/Rexfile` (DNS + ACME cert + relayd routing), the ingress
`host:` in `f3s/forgejo/helm-chart/templates/ingress.yaml`, and
`FORGEJO__server__DOMAIN`/`ROOT_URL`/`SSH_DOMAIN` in `deployment.yaml`. These
can drift from the live cluster state if someone pushes directly to the
Forgejo-hosted `conf` mirror (`ssh://git@code.f3s.buetow.org:2022/snonux/conf.git`,
the `forgejo` git remote) without also updating a local checkout that tracks
a different remote (e.g. Codeberg `master`) — `git status` on the "wrong"
checkout will look clean while the live ArgoCD-synced revision has already
moved. Compare `kubectl -n cicd get application forgejo -o
jsonpath='{.status.sync.revision}'` against `git log` on **each** remote
before assuming the repo and cluster agree.

## rocky push access

The plain `rocky` VM pushes to `snonux/*` over git+ssh as Forgejo user **`rocky`**
(not `paul`). Client key + `~/.ssh/config`: see
[`f3s-rocky-vm-setup` git remotes](../../f3s-rocky-vm-setup/references/git-remotes.md).

Server side (one-time):

```sh
# Create non-admin user (password printed once; SSH is the normal auth path)
kubectl -n services exec deploy/forgejo -- \
  forgejo admin user create \
  --username rocky \
  --email rocky@f3s.lan.buetow.org \
  --fullname 'rocky VM' \
  --random-password \
  --must-change-password=false

# Add ~/.ssh/id_ed25519_forgejo.pub from paul@rocky to user rocky
# (web UI: Settings → SSH / GPG Keys, or POST /api/v1/user/keys with a rocky token)

# Org write on all snonux repos: team Writers (includes_all_repositories, permission write)
# Create via API as admin, then PUT /api/v1/teams/<id>/members/rocky
```

LAN API base: `https://code.f3s.lan.buetow.org/api/v1`.
