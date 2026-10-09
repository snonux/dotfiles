# Network Traffic Troubleshooting

How to answer "something is eating the network" for f3s: which host, which
pod, which website, and — crucially — whether the fault is even inside the
house. Written up after the 2026-08-19/20 investigation, which took several
wrong turns worth not repeating.

Why the homelab can slow down normal browsing at all: `blowfish`/`fishfinger`
are remote OpenBSD gateways (see the [`f3s`](../../SKILL.md) hub), so
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
separately** (`curl -4` / `curl -6`) — see [IPv4 vs IPv6](network-traps.md#ipv4-vs-ipv6) for why.

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
