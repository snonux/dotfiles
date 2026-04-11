# Pi-hole on Raspberry Pi (pi2, pi3)

Pi-hole runs in **Docker** on **`pi2.lan.buetow.org`** and **`pi3.lan.buetow.org`** with **`network_mode: host`** (Rocky Linux 9, firewalld allows 53/tcp, 53/udp, `http`). Compose uses **`cap_add: [NET_ADMIN]`**, bind-mounts **`./etc-pihole:/etc/pihole`** and **`./etc-dnsmasq.d:/etc/dnsmasq.d`**. Secrets live in **`~/pihole/.env`** on each host (**`WEBPASSWORD`** is host-local, not in git).

**Client DNS (LAN):** prefer **`192.168.1.127`** (pi2), then **`192.168.1.128`** (pi3), then router fallback — see **`f3s/pihole/README.md`** in conf for `nmcli` examples.

**Kubernetes:** Pi-hole was moved off the cluster; **`f3s/argocd-apps/services/pihole.yaml`** has sync disabled, but **`dnsmasq.customDnsEntries`** stays aligned with the Pis’ wildcard (`address=/.f3s.lan.buetow.org/192.168.1.138`) if that app is ever re-enabled.

## LAN wildcard DNS

Homelab LAN hostnames under **`*.f3s.lan.buetow.org`** should resolve to the **CARP VIP** **`192.168.1.138`** (FreeBSD **f0/f1** → relayd → k3s Traefik). In **dnsmasq** (Pi-hole):

```text
address=/.f3s.lan.buetow.org/192.168.1.138
```

The leading **`.`** matches the apex and all subdomains.

## Tracked files in `conf`

In the **`f3s`** repo (`https://codeberg.org/snonux/conf`):

- **`f3s/pihole/docker-pi/dnsmasq.d/99-f3s-lan-wildcard.conf`** — copy into **`~/pihole/etc-dnsmasq.d/`** on each Pi (bind-mounted to `/etc/dnsmasq.d` in the live compose).
- **`f3s/pihole/docker-pi/docker-compose.example.yml`** — reference compose including the **`etc-dnsmasq.d`** volume; merge with your live **`docker-compose.yml`**.

After changing dnsmasq config: **`docker compose restart`** in **`~/pihole`**.

**Rollout (from a workstation with SSH):** copy **`99-f3s-lan-wildcard.conf`** to each Pi (e.g. `/tmp`), then `sudo install -o root -g root -m 644 … ~/pihole/etc-dnsmasq.d/`, remove any obsolete apex-only file (e.g. **`02-custom-f3s.conf`**), restart compose. Keep both nodes in sync.

## Verify

```bash
dig @pi2.lan.buetow.org foo.f3s.lan.buetow.org +short   # expect 192.168.1.138
dig @pi3.lan.buetow.org f3s.lan.buetow.org +short       # expect 192.168.1.138
```

Admin UI: **`http://pi2.lan.buetow.org/admin/`** (and pi3).

## Public DNS note

**`frontends/var/nsd/zones/master/buetow.org.zone.tpl`** already has **`*.f3s.lan IN A 192.168.1.138`** for authoritative **`buetow.org`**; Pi-hole on the LAN keeps the same mapping for clients that use pi2/pi3 as resolver.
