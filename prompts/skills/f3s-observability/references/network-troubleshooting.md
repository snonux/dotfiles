# Network Traffic Troubleshooting

How to answer "something is eating the network" for f3s: which host, which
pod, which website, and — crucially — whether the fault is even inside the
house. Written up after the 2026-08-19/20 investigation, which took several
wrong turns worth not repeating.

Why the homelab can slow down normal browsing at all: `blowfish`/`fishfinger`
are remote OpenBSD gateways (see the [`f3s`](../../f3s/SKILL.md) hub), so
*every* inbound request to a public f3s service is relayed over WireGuard
back to the home LAN. Public traffic and household browsing share one uplink.

## Order of Attack

Work outside-in. Each step either localises the fault or clears a whole class
of cause, and the early steps are cheap:

1. **Is it even your network?** — external control host (below)
2. **Inside the house or upstream?** — local-gateway vs internet ping
3. **Which host?** — `node_network_*` per instance
4. **Which pod?** — `container_network_*` (mind the hostNetwork trap)
5. **Which website/route?** — `traefik_*` per service

## 1. Is It Your Network At All?

The single most useful test: run the **same request against the same
destination from a host on a different network**, at the same moment. The
gateways are perfect for this — they are yours, reachable, and nowhere near
the home uplink.

```sh
# from home
ssh -A -J rex@fishfinger.buetow.org paul@f2.wg0 'sh -s quay.io 15' < probe.sh
# control: not on the home connection
ssh rex@fishfinger.buetow.org -p2 'sh -s quay.io 15' < probe.sh
```

A `probe.sh` that loops `curl` N times per address family and counts
ok/slow/fail is worth keeping around; single `curl` runs are useless here
because these faults are intermittent. **Always test IPv4 and IPv6
separately** (`curl -4` / `curl -6`) — see the IPv6 section below for why.

In the 2026-08-19 case this was decisive: `quay.io` scored 12/15 (v6) and
14/15 (v4) from home but **30/30 from Hetzner**, proving the registry was
healthy and the fault was home-side.

## 2. Inside the House, or the ISP?

Ping the **default gateway** (packets never leave the LAN) and an internet
host back to back, repeatedly, while the suspect load is running. If the
*local* hop degrades, the bottleneck is house-side — switch, AP, router — and
the ISP is exonerated. If only the internet hop degrades while local stays
clean, look upstream.

```sh
gw=$(netstat -rn -f inet | awk '$1=="default"{print $2; exit}')  # FreeBSD
ping -c 25 -q "$gw"; ping -c 25 -q 8.8.8.8
```

Sample this repeatedly *through* an event (e.g. a k3s restart) rather than
once — see the `watch_degrade.sh` pattern: interface rate + both RTTs on each
row.

**Read latency, not just bandwidth.** A saturated link shows *bufferbloat* —
RTT climbing into the tens or hundreds of ms. If throughput is high but RTT
stays flat and loss is 0%, the link is **not** the problem, and you should be
looking at connection state, DNS, or a specific destination instead. During a
231 Mbps internal burst the local hop stayed at 1.2 ms with 0% loss — that
burst was node-to-node traffic that never touched the WAN at all.

## 3. Which Host?

`node_network_*` from node-exporter, via Prometheus's NodePort on any r-node:

```sh
curl -sG "http://localhost:30090/api/v1/query" \
  --data-urlencode 'query=rate(node_network_transmit_bytes_total{device="wg0"}[5m])*8'
```

- `device="wg0"` — the WireGuard tunnel, i.e. the WAN-facing path
- `device="enp0s5"` (r-nodes) / `device="re0"` (f-hosts) — the LAN interface;
  usually much larger, and mostly etcd/apiserver/NFS that never leaves the LAN

Instances: f-hosts `192.168.2.130-132:9100`, gateways `192.168.2.110-111:9100`,
r-nodes `192.168.2.120-122:9100`.

Use `query_range` (`start`/`end`/`step`) for history — a real incident is a
**sustained multi-Mbps floor over hours**, not one spike.

## 4. Which Pod?

cAdvisor counters, ranked over a window:

```promql
topk(25, sum by (namespace, pod) (
  increase(container_network_receive_bytes_total{pod!=""}[3h])
))
```

Query receive and transmit **separately and merge client-side**. Adding them
in PromQL uses elementwise vector matching, which silently drops any pod that
only ever transmitted or only received — exactly the pods a traffic hunt
cares about.

### Trap: `hostNetwork: true` pods

**`prometheus-prometheus-node-exporter-*` will always top this list, and it
is an artifact.** Those pods run with `hostNetwork: true`, sharing the host's
network namespace, so cAdvisor attributes **the entire node's traffic** to
them. In the 2026-08-19 data they accounted for 91% of the "cluster total"
(33 GB / 18 GB / 10 GB) — which is really just per-node totals for r1/r2/r0.

Read them as host totals, or exclude them to get true per-app numbers.
Confirm with:

```sh
kubectl -n monitoring get pod <pod> -o jsonpath='{.spec.hostNetwork}'
```

## 5. Which Website / Route?

Per-pod bytes cannot tell you *which site* drove ingress. Traefik's own
metrics can, and are enabled via `f3s/traefik-config` (a `HelmChartConfig`
customising k3s's bundled Traefik) with `addRoutersLabels` /
`addServicesLabels`, plus a `serviceMonitor` carrying `release: prometheus`
(kube-prometheus-stack only scrapes ServiceMonitors with its own release
label).

```promql
sum by (exported_service) (rate(traefik_service_requests_total[5m]))
sum by (exported_service) (traefik_service_responses_bytes_total)
```

**The label is `exported_service`, not `service`.** Prometheus renames it on
collision with the ServiceMonitor's own `service` label; querying `service`
silently returns only Traefik's internal service and looks like "no traffic".

This is what finally identified the culprit: `cicd-git-server-80` at
2.1 req/s versus `services-forgejo-80` at 0.0.

## Coverage Gap: Traffic Traefik Never Sees

**Traefik metrics only cover HTTP that relayd forwards into the k3s Traefik
ingress.** A large share of internet-facing traffic bypasses it entirely, so
step 5 above will show *nothing* for these and they must be chased with pf /
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

### Design sketch: generic byte accounting on the gateways

Neither piece is deployed yet — `pfctl -sl` returns nothing (no labelled
rules) and `node_exporter` runs with only `--web.listen-address` (no textfile
collector, no `/var/node_exporter`).

1. **Count with pf labels.** `pf.conf.tpl` is currently a bare `pass` policy.
   Adding `match in ... label "svc_<name>"` rules per public port counts
   packets/bytes **without changing the pass/block decision** — `match` rules
   do not alter policy, so this is non-invasive. Then `pfctl -sl` emits
   `label evaluations packets bytes ...` per service.
2. **Export via node_exporter's textfile collector.** Add
   `--collector.textfile.directory=/var/node_exporter` to
   `node_exporter_flags` in `rc.conf.local`, and a cron job writing
   `pfctl -sl` into a `.prom` file as counters. Prometheus already scrapes
   both gateways (`192.168.2.110:9100`, `192.168.2.111:9100`, `os="openbsd"`),
   so the series appear with no scrape-config change.
3. **Inspect content** where volume alone is not enough: `pflog0` +
   `tcpdump -n -i pflog0` for packet-level, or the relayd session log above
   for who-talked-to-which-relay.

**Deploy pf changes one gateway at a time and verify SSH still works before
touching the second** — these are the public frontends, and a pf mistake
locks you out of the box you are editing.

## Worked Case: the Crawler That Moved (2026-08-19/20)

1. A crawler walked Forgejo's expensive blame/commit/diff pages, ~3-7.5 Mbps
   sustained. Blocked `code.f3s.buetow.org` at relayd.
2. **Traffic continued.** Blocking one hostname does not stop a bot that can
   find another door — it had moved to `c-git.f3s.buetow.org`, the legacy
   cgit UI, which renders equally expensive per-commit pages.
3. Only enabling Traefik metrics made this visible; per-pod counters were too
   coarse. Lesson: **verify the traffic actually stopped**, don't assume the
   block worked.

The relayd fix pattern (see `frontends/etc/relayd.conf.tpl`): `block request
header "Host" value "<host>"` inside the `"https"` protocol. Notes:

- **`block quick` is not valid relayd syntax here** — it fails
  `relayd -n`. Plain `block` is correct.
- Always `relayd -n` before deploying, and deploy **one gateway at a time**
  (a relayd restart briefly drops every public site on that gateway).
- Leave port 80 alone — it never proxies to the cluster (httpd handles
  ACME/redirect), and blocking it breaks certificate renewal.
- Keep a non-standard port alive if humans still need the UI (Forgejo kept
  one); skip that for a service nobody browses.

## Trap: Flaky Registry + `imagePullPolicy: Always`

A slow/flaky **external registry** turns into sustained internal load when a
manifest sets `imagePullPolicy: Always` on a **pinned version tag**: every
pod (re)start forces a live registry check even though the image is already
cached on every node. If that check fails, the pod backs off and retries —
forever. At k3s restart all ~30 apps resync at once and it becomes a storm.

cert-manager sat in `ErrImagePull`/`CrashLoopBackOff` for 9-10 days this way
against `quay.io` (measured failing ~1-in-5 requests from this network).
Fix: `IfNotPresent` for pinned tags.

Check whether the image is *already* cached before believing a pull error:

```sh
crictl images | grep <image>
kubectl get pods -A | grep -E 'ImagePullBackOff|ErrImagePull|CrashLoopBackOff'
```

Do **not** blanket-apply `IfNotPresent`: for `:latest` tags it silently
freezes updates, and for local-registry images re-pushed under the same tag
(`registry.lan.buetow.org:30001/...`) `Always` is load-bearing.

## IPv4 vs IPv6

Test address families separately — a fault in one is invisible if `curl`
picks the other. Observed here: several destinations (`quay.io`,
`www.google.com`) resolve **IPv6-only** from this network, so a v6-specific
problem looks like "that site is down" while everything else works.

Measured 2026-08-20: IPv4 was consistently the *healthier* path; IPv6 to
Google was mildly flaky (5s SYN-retransmit stalls, occasional timeouts) while
IPv6 to heise.de was 20/20 perfect — i.e. destination-specific, not a broken
local v6 stack. Don't generalise from one destination.

## NFS Is Usually Not It

NFS rides `stunnel` to the LAN CARP VIP over `127.0.0.1`/LAN and **never
touches `wg0`**, so it cannot cause a WAN-side slowdown regardless of volume.
Rule it out in seconds — zero `retrans` means healthy:

```sh
nfsstat -c   # on each r-node; check the retrans column
```

See [`f3s-storage`](../../f3s-storage/SKILL.md) for genuine NFS faults.

## Don't Trust Stale Notes

`f3s/references/hardware.md` claimed a TP-Link EAP615-Wall as the switch;
the gateway at `192.168.1.1` actually serves **`thttpd`** (not OpenWrt's
`uhttpd`), so that topology was wrong and an "AP is the bottleneck"
hypothesis built on it had to be dropped. Fingerprint the live network before
theorising:

```sh
curl -s -I --max-time 5 "http://$gw/" | head
arp -an
ifconfig re0 | grep -E 'media|status'   # confirm negotiated link speed
```
