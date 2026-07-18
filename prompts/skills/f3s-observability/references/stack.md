# Observability Stack (k3s side)

Install and operation of the in-cluster observability components: Prometheus,
Alloy, Loki, Tempo, Alertmanager → Gogios.

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

### Disabled component manifests

These files exist in the repo but are renamed `.disabled` so ArgoCD ignores them:
```
f3s/argocd-apps/monitoring/loki.yaml.disabled
f3s/argocd-apps/monitoring/tempo.yaml.disabled
f3s/argocd-apps/monitoring/grafana-ingress.yaml.disabled
```

To re-enable, rename back to `.yaml` and ensure Grafana is using a non-NFS PVC (local-path).

## Installing Prometheus

Uses `kube-prometheus-stack` Helm chart with **Grafana subchart disabled** (`grafana.enabled: false`):

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create NFS storage directory first
mkdir -p /data/nfs/k3svolumes/prometheus/data

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

Also requires k3s config changes on each r node — see [k3s-setup/install.md](../../f3s-k3s/references/install.md).

### Grafana credentials

Default: `admin` / `prom-operator` — change immediately after first login.

Grafana accessible at `grafana.f3s.foo.zone` via Traefik ingress.

## Installing Alloy (minimal)

Alloy is installed as part of the Loki Helm chart but runs with a minimal config (no log shipping):

```sh
cd conf/f3s/loki && just install
# installs alloy only (loki itself is disabled via loki.yaml.disabled)
```

### Current Alloy config (`alloy-values.yaml`)

Minimal — only emits Alloy's own operational logs:

```
logging {
  level = "info"
}
```

To re-enable log shipping (once Loki is running again), restore the full `discovery.kubernetes` + `loki.source.kubernetes` + `loki.write` pipeline.

## Installing Loki (disabled)

```sh
mkdir -p /data/nfs/k3svolumes/loki/data
# Rename loki.yaml.disabled → loki.yaml first, then:
cd conf/f3s/loki && just install
```

Loki URL (internal): `http://loki.monitoring.svc.cluster.local:3100`

## Installing Tempo (disabled)

```sh
mkdir -p /data/nfs/k3svolumes/tempo/data
# Rename tempo.yaml.disabled → tempo.yaml first, then:
cd conf/f3s/tempo && just install
```

## Alerting

Prometheus → Alertmanager → **Gogios** (custom lightweight monitoring tool running on OpenBSD gateway `blowfish`/`fishfinger`).

Gogios scrapes Alertmanager at regular intervals and sends email notifications. Reaches Alertmanager via WireGuard mesh.

## Prometheus TSDB Recovery

If Prometheus fails to start with `opening storage failed: get segment range: segments are not sequential`, WAL segments are corrupt (can happen after a cluster blip leaving zero-byte WAL files).

Full TSDB wipe (loses all historical data — confirm first):

```sh
# On the NFS server (f0 or CARP MASTER)
rm -rf /data/nfs/k3svolumes/prometheus/data/prometheus-db/
mkdir -p /data/nfs/k3svolumes/prometheus/data/prometheus-db
chown 1000:1000 /data/nfs/k3svolumes/prometheus/data/prometheus-db
# Prometheus will recreate the TSDB on next start
```

## Useful LogQL Queries

```
# All logs from services namespace
{namespace="services"}

# Filter by log content
{namespace="services"} |= "error"

# Parse JSON logs
{namespace="services"} | json | level="error"
```

## NFS Storage Paths

```
/data/nfs/k3svolumes/prometheus/data   # active
/data/nfs/k3svolumes/grafana/data      # exists but unused (grafana disabled)
/data/nfs/k3svolumes/loki/data         # exists but unused (loki disabled)
/data/nfs/k3svolumes/tempo/data        # exists but unused (tempo disabled)
```
