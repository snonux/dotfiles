---
name: f3s-observability
description: Reference skill for the f3s homelab observability stack, Prometheus, Grafana Alloy, Loki, Tempo, and alerting on the k3s cluster, plus FreeBSD host monitoring (node_exporter + recording rules). Use when working on metrics, logs, traces, dashboards, or alerts for the homelab. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# f3s Observability Stack

Observability stack deployed into the `monitoring` namespace of the k3s cluster.

**Current state (as of 2026-05-16)**: Prometheus + Alloy only. Grafana, Loki, and Tempo are **disabled** — their ArgoCD manifests are renamed to `.disabled` and their pods do not run.

- Grafana disabled: SQLite-on-NFS is fundamentally unreliable across pod restarts. Grafana's database gets locked when the pod reschedules to a different node. Long-term fix: migrate to local-path PVC (same pattern as navidrome).
- Loki/Tempo disabled: no log aggregation or distributed tracing until Grafana is re-enabled.
- Alloy is running but **only emits its own logs** (`logging { level = "info" }`). Log shipping to Loki and trace forwarding to Tempo are removed from its config.
- Prometheus TSDB was wiped and restarted clean (2026-05-16) after WAL corruption (zero-byte segments from a cluster blip).

## Components

| Component | Purpose | State |
|-----------|---------|-------|
| **Prometheus** | Time-series metrics, alerting rules, Alertmanager | **Running** |
| **Alloy** | Telemetry collector (DaemonSet) | **Running** (minimal config only) |
| **Node Exporter** | Host-level metrics (on k3s nodes AND FreeBSD hosts) | **Running** |
| **Grafana** | Visualisation and dashboarding | **Disabled** (SQLite-on-NFS) |
| **Loki** | Log aggregation (single-binary mode) | **Disabled** |
| **Tempo** | Distributed tracing backend | **Disabled** |

## When to Use

- Working on metrics, logs, traces, dashboards, or alerts for the homelab
- Prometheus/Alloy config, alerting, TSDB recovery, or FreeBSD host monitoring
- For the k3s cluster this runs on, see [`f3s-k3s`](../f3s-k3s/SKILL.md); for hosts/IPs, the [`f3s`](../f3s/SKILL.md) hub.

## Reference Files

- [Stack](references/stack.md) — install Prometheus / Alloy / Loki / Tempo, alerting → Gogios, Prometheus TSDB recovery, LogQL queries, NFS storage paths
- [FreeBSD Monitoring](references/freebsd.md) — `node_exporter` on f-hosts, scrape config, memory & ZFS recording rules

## Monitoring Scope

- Kubernetes workloads (pod health, resource usage)
- Node-level metrics (CPU, memory, disk) — both k3s and FreeBSD nodes
- ZFS ARC statistics on FreeBSD hosts
- Application performance metrics
- ~~Log aggregation from all pods (via Alloy → Loki)~~ — disabled
- ~~Distributed traces (via Alloy → Tempo)~~ — disabled
