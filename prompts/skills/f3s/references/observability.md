# f3s Observability Stack (area index)

Observability stack deployed into the `monitoring` namespace of the k3s cluster.

**Current state (as of 2026-09-25)**: Prometheus only. Grafana, Loki, Tempo and Alloy are **disabled** — their ArgoCD manifests are renamed to `.disabled` and their pods do not run.

- Grafana disabled: SQLite-on-NFS is fundamentally unreliable across pod restarts. Grafana's database gets locked when the pod reschedules to a different node. Long-term fix: migrate to local-path PVC (same pattern as navidrome).
- Loki/Tempo disabled: no log aggregation or distributed tracing until Grafana is re-enabled.
- Alloy was disabled 2026-09-25 (audit #16): its no-op config only sent Grafana Labs usage reports. The Grafana/Loki/Tempo PV/PVCs were deleted too; the NFS data stays in `/data/nfs/k3svolumes/{grafana,loki}/data` (28M / 2.8G). `grafana.f3s.buetow.org` no longer exists on the frontends (DNS, relayd, acme, Gogios).
- Prometheus TSDB was wiped and restarted clean (2026-05-16) after WAL corruption (zero-byte segments from a cluster blip).

## Components

| Component | Purpose | State |
|-----------|---------|-------|
| **Prometheus** | Time-series metrics, alerting rules, Alertmanager | **Running** |
| **Alloy** | Telemetry collector (DaemonSet) | **Disabled** (was a no-op) |
| **Node Exporter** | Host-level metrics (on k3s nodes AND FreeBSD hosts) | **Running** |
| **Grafana** | Visualisation and dashboarding | **Disabled** (SQLite-on-NFS) |
| **Loki** | Log aggregation (single-binary mode) | **Disabled** |
| **Tempo** | Distributed tracing backend | **Disabled** |

## When to Use

- Working on metrics, logs, traces, dashboards, or alerts for the homelab
- Prometheus/Alloy config, alerting, TSDB recovery, or FreeBSD host monitoring
- "Something is eating the network" investigations
- Building, deploying or updating Gogios (the monitoring that Prometheus alerts are routed to)
- For the k3s cluster this runs on, see [k3s cluster](k3s.md); for hosts/IPs, the [hub](../SKILL.md).

## Topic Files

- [Stack](observability/stack.md) — install Prometheus / Alloy / Loki / Tempo, alerting → Gogios, Prometheus TSDB recovery, LogQL queries, NFS storage paths
- [FreeBSD Monitoring](observability/freebsd.md) — `node_exporter` on f-hosts, scrape config, memory & ZFS recording rules
- [Gogios](observability/gogios.md) — build, sign and publish the Gogios OpenBSD package (`make pkg-openbsd NAME=gogios`), then install it on both frontends with `./gonf.sh cluster frontends frontends_gogios`; `pkg_add -u` pkgpath and `PKG_PATH` pitfalls

Network traffic troubleshooting (three files; start with the triage):

- [Network triage](observability/network-triage.md) — the order of attack: is it your network at all, inside the house or the ISP, which host, which pod (the `hostNetwork` cAdvisor trap), which website (Traefik per-service metrics, `exported_service`)
- [pf label accounting](observability/network-pf-accounting.md) — the coverage gap: traffic Traefik never sees; what already exists, the deployed pf label accounting on the gateways, example PromQL queries
- [Worked case & traps](observability/network-traps.md) — the crawler that moved (2026-08-19/20) and the relayd block pattern, flaky-registry `imagePullPolicy` trap, IPv4-vs-IPv6 probing, why NFS is usually not it, stale notes

## Monitoring Scope

- Kubernetes workloads (pod health, resource usage)
- Node-level metrics (CPU, memory, disk) — both k3s and FreeBSD nodes
- ZFS ARC statistics on FreeBSD hosts
- Application performance metrics
- ~~Log aggregation from all pods (via Alloy → Loki)~~ — disabled
- ~~Distributed traces (via Alloy → Tempo)~~ — disabled
