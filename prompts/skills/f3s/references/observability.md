# Observability Stack

## Overview

Complete observability stack deployed into the `monitoring` namespace of the k3s cluster.

Stack: **PLG + Tempo** (Prometheus, Loki, Grafana + Tempo for distributed tracing)

## Components

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Time-series metrics, alerting rules, Alertmanager |
| **Grafana** | Visualisation and dashboarding |
| **Loki** | Log aggregation (single-binary mode) |
| **Alloy** | Telemetry collector (DaemonSet) — ships logs to Loki, traces to Tempo |
| **Tempo** | Distributed tracing backend |
| **Node Exporter** | Host-level metrics (on k3s nodes AND FreeBSD hosts) |

## Deployment

All components deployed via **ArgoCD** (GitOps). Manifests:
```
https://codeberg.org/snonux/conf/src/branch/master/f3s
argocd-apps/monitoring/
```

Deployment tool: `just` (Justfile in each component directory).

### Namespaces

```sh
kubectl create namespace monitoring
```

## Installing Prometheus + Grafana

Uses `kube-prometheus-stack` Helm chart:

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create NFS storage directories first
mkdir -p /data/nfs/k3svolumes/prometheus/data
mkdir -p /data/nfs/k3svolumes/grafana/data

cd conf/f3s/prometheus && just install
```

### Enable etcd and controller-manager scraping

Add to `persistence-values.yaml`:

```yaml
kubeEtcd:
  enabled: true
  endpoints: [192.168.2.120, 192.168.2.121, 192.168.2.122]
  service:
    port: 2381
    targetPort: 2381

kubeControllerManager:
  enabled: true
  endpoints: [192.168.2.120, 192.168.2.121, 192.168.2.122]
  service:
    port: 10257
    targetPort: 10257
  serviceMonitor:
    enabled: true
    https: true
    insecureSkipVerify: true
```

Also requires k3s config changes on each r node — see k3s-setup.md.

### Grafana credentials

Default: `admin` / `prom-operator` — change immediately after first login.

Grafana accessible at `grafana.f3s.foo.zone` via Traefik ingress.

## Installing Loki + Alloy

```sh
mkdir -p /data/nfs/k3svolumes/loki/data
cd conf/f3s/loki && just install
# installs both loki and alloy
```

Loki URL (internal): `http://loki.monitoring.svc.cluster.local:3100`

Add Loki as Grafana data source: Configuration → Data Sources → Loki → URL above.

### Alloy configuration (`alloy-values.yaml`)

```
discovery.kubernetes "pods" {
  role = "pod"
}

discovery.relabel "pods" {
  targets = discovery.kubernetes.pods.targets
  rule { source_labels = ["__meta_kubernetes_namespace"]; target_label = "namespace" }
  rule { source_labels = ["__meta_kubernetes_pod_name"]; target_label = "pod" }
  rule { source_labels = ["__meta_kubernetes_pod_container_name"]; target_label = "container" }
  rule { source_labels = ["__meta_kubernetes_pod_label_app"]; target_label = "app" }
}

loki.source.kubernetes "pods" {
  targets    = discovery.relabel.pods.output
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint {
    url = "http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push"
  }
}
```

## Installing Tempo

```sh
mkdir -p /data/nfs/k3svolumes/tempo/data
cd conf/f3s/tempo && just install
```

Add Tempo as Grafana data source: Grafana → Configuration → Data Sources → Tempo.

## Monitoring FreeBSD Hosts (f0, f1, f2)

### Install node_exporter on FreeBSD

```sh
# On each FreeBSD host
doas pkg install -y node_exporter
doas sysrc node_exporter_enable=YES
# Bind to WireGuard interface (f0=192.168.2.130, f1=192.168.2.131, f2=192.168.2.132)
doas sysrc node_exporter_args='--web.listen-address=192.168.2.130:9100'
doas service node_exporter start
```

### Prometheus scrape config for FreeBSD

`additional-scrape-configs.yaml`:

```yaml
- job_name: 'node-exporter'
  static_configs:
    - targets:
      - '192.168.2.130:9100'  # f0 via WireGuard
      - '192.168.2.131:9100'  # f1 via WireGuard
      - '192.168.2.132:9100'  # f2 via WireGuard
      labels:
        os: freebsd
```

```sh
kubectl create secret generic additional-scrape-configs \
    --from-file=additional-scrape-configs.yaml -n monitoring
```

Add to `persistence-values.yaml`:

```yaml
prometheus:
  prometheusSpec:
    additionalScrapeConfigsSecret:
      enabled: true
      name: additional-scrape-configs
      key: additional-scrape-configs.yaml
```

### FreeBSD memory compatibility rules

FreeBSD uses different metric names than Linux. PrometheusRule to create Linux-compatible metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: freebsd-memory-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: freebsd-memory
      rules:
        - record: node_memory_MemTotal_bytes
          expr: node_memory_size_bytes{os="freebsd"}
        - record: node_memory_MemAvailable_bytes
          expr: |
            node_memory_free_bytes{os="freebsd"}
              + node_memory_inactive_bytes{os="freebsd"}
              + node_memory_cache_bytes{os="freebsd"}
        - record: node_memory_MemFree_bytes
          expr: node_memory_free_bytes{os="freebsd"}
        - record: node_memory_Buffers_bytes
          expr: node_memory_buffer_bytes{os="freebsd"}
        - record: node_memory_Cached_bytes
          expr: node_memory_cache_bytes{os="freebsd"}
```

Note: Disk I/O metrics (`node_disk_*`) are not available on FreeBSD — use ZFS-specific dashboards instead.

### ZFS monitoring recording rules

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: freebsd-zfs-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: freebsd-zfs-arc
      interval: 30s
      rules:
        - record: node_zfs_arc_hit_rate_percent
          expr: |
            100 * (
              rate(node_zfs_arcstats_hits_total{os="freebsd"}[5m]) /
              (rate(node_zfs_arcstats_hits_total{os="freebsd"}[5m]) +
               rate(node_zfs_arcstats_misses_total{os="freebsd"}[5m]))
            )
        - record: node_zfs_arc_memory_usage_percent
          expr: |
            100 * (
              node_zfs_arcstats_size_bytes{os="freebsd"} /
              node_zfs_arcstats_c_max_bytes{os="freebsd"}
            )
```

## Alerting

Prometheus → Alertmanager → **Gogios** (custom lightweight monitoring tool running on OpenBSD gateway `blowfish`/`fishfinger`).

Gogios scrapes Alertmanager at regular intervals and sends email notifications. Reaches Alertmanager via WireGuard mesh.

## Monitoring Scope

- Kubernetes workloads (pod health, resource usage)
- Node-level metrics (CPU, memory, disk) — both k3s and FreeBSD nodes
- ZFS ARC statistics on FreeBSD hosts
- Application performance metrics
- Log aggregation from all pods (via Alloy → Loki)
- Distributed traces (via Alloy → Tempo)

## Useful LogQL Queries

```
# All logs from services namespace
{namespace="services"}

# Filter by log content
{namespace="services"} |= "error"

# Parse JSON logs
{namespace="services"} | json | level="error"
```

## NFS Storage Paths for Observability

```
/data/nfs/k3svolumes/prometheus/data
/data/nfs/k3svolumes/grafana/data
/data/nfs/k3svolumes/loki/data
/data/nfs/k3svolumes/tempo/data
```
