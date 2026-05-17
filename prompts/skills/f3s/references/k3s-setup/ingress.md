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
