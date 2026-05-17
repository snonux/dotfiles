# Monitoring FreeBSD Hosts (f0, f1, f2)

Scraping the FreeBSD bhyve hosts from in-cluster Prometheus. Includes the
node_exporter setup, the additional scrape config, and the recording rules
that bridge FreeBSD metric names into the Linux-style names Grafana
dashboards expect.

## Install node_exporter on FreeBSD

```sh
# On each FreeBSD host
doas pkg install -y node_exporter
doas sysrc node_exporter_enable=YES
# Bind to WireGuard interface (f0=192.168.2.130, f1=192.168.2.131, f2=192.168.2.132)
doas sysrc node_exporter_args='--web.listen-address=192.168.2.130:9100'
doas service node_exporter start
```

## Prometheus scrape config for FreeBSD

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

## FreeBSD memory compatibility rules

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

## ZFS monitoring recording rules

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
