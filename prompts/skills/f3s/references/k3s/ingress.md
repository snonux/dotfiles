# k3s Ingress (Internet + LAN)

Two ingress paths into the k3s cluster:
- **Internet → OpenBSD relayd** (TLS termination on `blowfish`/`fishfinger`) → WireGuard → Traefik
- **LAN → FreeBSD relayd on CARP VIP** → k3s Traefik

## External Connectivity: OpenBSD relayd

Default traffic flow for public k3s-backed services: `Internet → OpenBSD relayd (TLS, Let's Encrypt) → WireGuard → k3s Traefik :80 → Service`

### relayd.conf on blowfish/fishfinger

```
table <f3s> {
  192.168.2.120
  192.168.2.121
  192.168.2.122
}

http protocol "https" {
    tls keypair f3s.foo.zone
    # ... all f3s service TLS keypairs ...
    # Non-f3s hosts explicitly forwarded to localhost:
    match request header "Host" value "foo.zone" forward to <localhost>
    # f3s hosts have NO match rules — use relay-level failover
}

relay "https4" {
    listen on <PUBLIC_IP> port 443 tls
    protocol "https"
    forward to <f3s> port 80 check tcp      # primary
    forward to <localhost> port 8080         # fallback when f3s down
}
```

`f3s.buetow.org` is now a special case: it no longer points at the k3s/apache backend and is forwarded by OpenBSD `relayd` to `pi0` (`192.168.2.203`) and `pi1` (`192.168.2.204`) via a dedicated `<f3s_static>` backend table.

When all k3s-backed f3s nodes are down, relayd falls back to `localhost:8080` (OpenBSD httpd serving a "Server turned off" page) for the hosts that still use the shared `<f3s>` backend.

## LAN Ingress: FreeBSD relayd on CARP VIP

For LAN access without going through internet gateways:
`LAN → CARP VIP (192.168.1.138) → FreeBSD relayd → k3s Traefik :443 → Service`

### FreeBSD relayd config (`/usr/local/etc/relayd.conf`)

```
table <k3s_nodes> { 192.168.1.120 192.168.1.121 192.168.1.122 }

relay "lan_http" {
    listen on 192.168.1.138 port 80
    forward to <k3s_nodes> port 80 check tcp
}

relay "lan_https" {
    listen on 192.168.1.138 port 443
    forward to <k3s_nodes> port 443 check tcp
}
```

Minimal `/etc/pf.conf` (PF required for relayd):

```
set skip on lo0
pass in quick
pass out quick
```

```sh
doas pkg install -y relayd
doas sysrc pf_enable=YES pflog_enable=YES relayd_enable=YES
doas service pf start && doas service pflog start && doas service relayd start
```

Run on both f0 and f1. Only CARP MASTER responds to VIP traffic.

Since 2026-09-25 (task mk2) gonf manages all of this on f0/f1 — do not
hand-edit: `gonf/freebsd/relayd.go`, sources in `f3s/freebsd-hosts/relayd/`,
tasks `freebsd_relayd_rc_conf` (pf_enable/pflog_enable), `freebsd_relayd_pf`
(pf.conf, validated with `pfctl -nf`, `pfctl -f` only on change) and
`freebsd_relayd_daemon` (package, relayd.conf validated with `relayd -n -f`,
relayd_enable via the service backend, **restart** only on change). Roll out
one host at a time, BACKUP first:
`./gonf.sh push -privilege doas -- -p 22 paul@f1.lan.buetow.org freebsd_relayd_pf freebsd_relayd_daemon`,
then check a new ssh (LAN + WireGuard), `curl -k https://immich.f3s.lan.buetow.org`,
and CARP state, then f0.

### cert-manager for LAN TLS

LAN services use `*.f3s.lan.foo.zone` with a self-signed CA managed by cert-manager:

```sh
cd conf/f3s/cert-manager && just install
# Creates: selfsigned ClusterIssuer, CA cert, wildcard cert (f3s-lan-tls)
```

Copy secret to service namespace:
```sh
kubectl get secret f3s-lan-tls -n cert-manager -o yaml | \
    sed 's/namespace: cert-manager/namespace: services/' | \
    kubectl apply -f -
```

### LAN ingress pattern

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-lan
  namespace: services
  annotations:
    spec.ingressClassName: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  tls:
    - hosts:
        - myservice.f3s.lan.foo.zone
      secretName: f3s-lan-tls
  rules:
    - host: myservice.f3s.lan.foo.zone
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myservice
                port:
                  number: 8080
```

## Encoded characters in request paths (Traefik >= 3.6)

Since the k3s v1.36.4 upgrade (2026-09-25) the bundled Traefik is 3.7.8
(chart 40.1.4). At startup it logs `WRN Traefik can reject some encoded
characters in the request path ... set these options to false to avoid
split-view` -- this is advisory only. The options are
`entryPoints.<name>.http.encodedCharacters.allowEncodedSlash`,
`allowEncodedBackSlash`, `allowEncodedNullCharacter`, `allowEncodedSemicolon`,
`allowEncodedPercent`, `allowEncodedQuestionMark`, `allowEncodedHash`; since
v3.6.7 they all default to `true` (allow), so nothing is rejected
(migration notes: doc.traefik.io/traefik/v3.7/migrate/v3/). `sanitizePath`
stays at its default (on). **No override is set in `f3s/traefik-config`, and
none is needed.**

Verified 2026-09-25 (task wk2) on both entrypoints -- `web` :80 (public, via
OpenBSD relayd) and `websecure` :443 (LAN VIP `*.f3s.lan.buetow.org`):

- Scratch rclone WebDAV behind a throwaway ingress: PUT/GET/PROPFIND/DELETE
  round-trip of `a;b%20c#d.txt`, `ü ö.txt`, `x%2Fy.txt` (sent as `x%252Fy`),
  `50%.txt`, `q?.txt`, `back\slash.txt` -- names land byte-exact on disk.
- Immich: upload/download of `wk2 a;b%20c#d ü.jpg` via API on both hosts
  (file name travels in multipart/Content-Disposition, not the path).
- webdav, filebrowser (`/api/resources|raw|tus/<name>`), radicale, syncthing,
  navidrome, jellyfin: unauthenticated probes with `%3B %2F %25 %3F %23 %5C
  %00 %2520` and UTF-8 all reach the backend (backend `Server` header /
  backend access log shows the raw encoded path) -- never a Traefik 400.

Backend-side quirks, not Traefik: Apache webdav answers 404 for a raw `%2F`
or `%00` in the path (`AllowEncodedSlashes Off`; a real file can't contain
`/` and clients send a literal `%2F` as `%252F`, which works); rclone treats
raw `%2F` as a separator (409); jellyfin (Kestrel) 400s on `%00`.
