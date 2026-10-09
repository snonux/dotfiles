# Traffic Traefik never sees: pf label accounting

## Coverage Gap: Traffic Traefik Never Sees

**Traefik metrics only cover HTTP that relayd forwards into the k3s Traefik
ingress.** A large share of internet-facing traffic bypasses it entirely, so
step 5 of the [triage](network-triage.md) will show *nothing* for these and they must be chased with pf /
relayd logs instead. From `frontends/etc/relayd.conf.tpl`:

| Public listener | Backend | Why Traefik can't see it |
|---|---|---|
| `:1965` gemini4/6 | local `:11965` | Gemini protocol, not HTTP |
| `:2022` forgejo_ssh4/6 | NodePort `30222` | plain TCP relay, git+ssh |
| `:443` → `<f3s_static_proxy>` | **pi0/pi1** `:80` bozohttpd | static `f3s.buetow.org` / `snonux.foo` served off the Pis, never enters k3s |
| `:443` → `<f3s_jellyfin>` | NodePort `30096` | deliberately bypasses Traefik (double-proxy issues) |
| `:443` → `<f3s_anki>` | NodePort `30800` | deliberately bypasses Traefik (zstd stream failures) |
| `:443` → `<garage>` | f-hosts `:3900` | Garage S3 API direct to FreeBSD hosts |
| `:443` → `<f3s_registry>` | NodePort `30001` | direct to registry |
| `:443`/`:80` → `<localhost>` | OpenBSD httpd `:8080` | foo.zone, gogios etc. — httpd's own logs |
| UDP `:56709` | WireGuard | tunnel itself; also carries roaming clients' **full-tunnel** internet traffic, NAT'd out via `match out ... nat-to` in `pf.conf` |

So "Traefik says 0 req/s" does **not** mean "no traffic" — check this table
before concluding the gateways are idle.

### What already exists

`relayd.conf.tpl` begins with `log connection`, so **every relayd session is
already logged** to `/var/log/daemon` on the gateways, tagged with the relay
name and both endpoints:

```
relayd[42839]: relay f3s_static_proxy4, session 88 (1 active), 0,
               127.0.0.1 -> 192.168.2.203:80, last write (done)
```

That covers gemini, forgejo_ssh, the Pi static sites and the NodePort relays
— i.e. exactly the rows above. Aggregating by relay name gives per-service
session counts for free:

```sh
doas awk '/relayd\[/ && /relay /{for(i=1;i<=NF;i++) if($i=="relay"){print $(i+1); break}}' \
    /var/log/daemon | sed 's/,$//' | sort | uniq -c | sort -rn
```

Caveat: this counts **sessions, not bytes**, and `newsyslog` rotates the log.

### pf label accounting (deployed)

**Per-service byte/packet counters for every public port, in Prometheus.**
This is the tool for the table above: pf sits underneath relayd, httpd and
the tunnels, so it sees traffic Traefik structurally cannot.

It measures at **two layers**, which is what makes services separable:

| Layer | Labels | What it answers |
|---|---|---|
| Front door (`in on vio0`) | `svc_*` | how much arrived on each public port |
| Backend leg (`out on wg0`) | `dst_*` | which service it was actually for |

The front door alone is not enough: every TLS service arrives on `:443`, so
Immich, foo.zone, the Pi static sites and Jellyfin all land in `svc_https`
together. They only separate once relayd picks a backend.

**Labels**

- Front door: `svc_https`, `svc_http`, `svc_gemini`, `svc_forgejo_web_alt`,
  `svc_forgejo_ssh`, `svc_dserver`, `svc_ssh_admin`, `svc_wireguard`
- Backend: `dst_traefik` (k3s ingress), `dst_pi_static` (**pi0/pi1**
  bozohttpd), `dst_jellyfin`, `dst_anki`, `dst_garage`, `dst_registry`,
  `dst_forgejo_ssh`
- Mesh: `wg_mesh_in` — everything inbound from f-hosts, r-nodes, Pis and
  roaming clients

Series: `pf_label_bytes_in_total`, `pf_label_bytes_out_total`,
`pf_label_packets_total`, `pf_label_states_total`. Instances are the two
gateways, `192.168.2.110:9100` (blowfish) and `192.168.2.111:9100`
(fishfinger). Retention is Prometheus's usual **10 days**.

Expect blowfish to carry almost all HTTPS while fishfinger looks idle —
whichever gateway holds the DNS master IP takes the traffic, so a lopsided
split is normal, not a fault. Sum across `instance` unless comparing them.

### Example queries

Prometheus has no ingress; reach it on the NodePort at
`http://r0.lan.buetow.org:30090` (LAN only — off-LAN needs the WireGuard
route or a port-forward).

```promql
# Per-service throughput right now, bits/sec, both gateways combined.
# `in` is what clients sent us; swap to _out_ for what we served back --
# on a 50 Mbit uplink the outbound figure is the one that hurts.
sum by (label) (rate(pf_label_bytes_in_total[5m])) * 8
sum by (label) (rate(pf_label_bytes_out_total[5m])) * 8

# Which service served the most data over the last day.
topk(5, sum by (label) (increase(pf_label_bytes_out_total[24h])))

# Backend leg only: which service was the traffic really for?
# This is the one that separates Jellyfin/anki/Pi-static from the :443 blob.
sum by (label) (rate(pf_label_bytes_out_total{label=~"dst_.*"}[5m])) * 8

# Traffic to the Raspberry Pi static sites specifically.
sum(rate(pf_label_bytes_out_total{label="dst_pi_static"}[5m])) * 8

# Split per gateway -- confirms which one is actually serving.
sum by (instance, label) (rate(pf_label_bytes_in_total{label="svc_https"}[5m])) * 8

# New connections/sec per service: distinguishes a crawler (many small
# connections) from a big download (few connections, many bytes).
sum by (label) (rate(pf_label_states_total[5m]))

# Sanity check that accounting is alive on both gateways (expect 2).
count by (instance) (pf_label_bytes_in_total)
```

Cross-checking against the other layers:

```promql
# HTTP share, per website (Traefik) -- pairs with dst_traefik above
sum by (exported_service) (rate(traefik_service_requests_total[5m]))

# Host-level totals, for comparison with the pf figures
rate(node_network_transmit_bytes_total{device="wg0"}[5m]) * 8
```

Straight off the gateway, no Prometheus needed:

```sh
doas pfctl -sl    # label evals packets bytes in-pkts in-bytes out-pkts out-bytes states
```

The packet and byte pairs **interleave**, so the column numbers are easy to
get wrong and an off-by-one silently reports packet counts as bytes (this
happened once already). Fields are `$1`=label, `$3`=packets, `$4`=bytes,
`$6`=bytes-in, `$8`=bytes-out, `$9`=states. Sanity check any change with
`$6 + $8 == $4`, and cross-check one exported value against `pfctl` output
before believing a dashboard.

**What it does and does not tell you.** Counters are per *pf rule*, so
`svc_https` is all of port 443 aggregated. It answers "how much, via which
port, to which backend" — never "which website". For per-site HTTP use the
Traefik metrics (step 5); for the non-HTTP relays use the relayd session log
above. The layers are complementary — keep both.

**Known gap**: `svc_wireguard` counts only tunnels the *remote peer*
initiated (UDP 56709 inbound on `vio0`); flows the gateway starts match the
earlier unlabelled `pass` and are not attributed. The `dst_*` labels cover
the same traffic one layer up, already decrypted and split by service, so
this is rarely worth chasing.

#### How it is wired

- `frontends/etc/pf.conf.tpl` — labelled rules at the **end** of the file
- `frontends/scripts/pf-labels-exporter.sh` — renders `pfctl -sl` as
  Prometheus counters, written atomically
- conf gonf task `frontends_pf` (`gonf/frontends/web.go`) — validates
  `pf.conf` with `pfctl -n` before replacing it and reloads PF on change;
  installs the script, `/var/node_exporter`, a root crontab entry (every
  minute), and sets `node_exporter` flags

Deploy from `~/git/conf` with `./gonf.sh cluster frontends frontends_pf` (both
gateways), or for one gateway
`./gonf.sh push -privilege=doas -- -p 2 rex@<gateway>.buetow.org frontends_pf`.
Prometheus already scrapes both gateways, so nothing changes on the scrape side.

**Adding a service**: append one labelled rule to `pf.conf.tpl` and re-run
`frontends_pf`. No exporter or scrape-config change needed.

#### Two things that are easy to get wrong

- **Use `pass`, not `match`.** A labelled `match` rule creates no state, so
  its byte counters stay at zero forever. The rules must also be **last** in
  the file: pf is last-match-wins, so being last makes them the
  state-creating rule for their ports. Policy is unaffected either way — the
  bare `pass` earlier in the file already permits this traffic.
- **No address family is specified**, so each rule covers IPv4 and IPv6
  together. Deliberate: the two families behave differently on this
  connection, and a v4-only fault is otherwise invisible.

#### Safe deployment

These are the public frontends and a pf mistake locks you out of the box you
are editing. Validate, then deploy **one gateway at a time**, confirming SSH
and a couple of sites in between:

```sh
doas pfctl -nf /tmp/pf.conf.test    # dry-run parse, does not load
```

Also confirm the egress interface name before trusting hardcoded rules
(`vio0` on both gateways today):

```sh
netstat -rn -f inet | awk '$1=="default"{print $NF; exit}'
```

For packet-level inspection when volume alone is not enough:
`tcpdump -n -i pflog0`.
