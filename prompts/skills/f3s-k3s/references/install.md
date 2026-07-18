# k3s Install

3-node HA k3s cluster running on Rocky Linux VMs (r0, r1, r2). All nodes act as both control-plane and etcd members (no separate worker nodes).

- k3s version: **v1.32.6+k3s1** (as of Part 7)
- etcd mode: **embedded HA** (`--cluster-init`)
- All control-plane traffic goes over **WireGuard** (192.168.2.x IPs)

## Prerequisites

- All Rocky Linux VMs (r0, r1, r2) updated and running
- WireGuard mesh fully configured (see [wireguard.md](../../f3s/references/wireguard.md))
- NVMe disk emulation in place (see [rocky-linux-vms.md](../../f3s/references/rocky-linux-vms.md)) — critical for etcd performance

## Installation

### Generate shared token

```sh
# On Fedora laptop
pwgen -n 32
# Copy output to all r nodes:
echo -n SECRET_TOKEN > ~/.k3s_token  # on r0, r1, r2
```

### Bootstrap first node (r0)

```sh
[root@r0 ~]# curl -sfL https://get.k3s.io | K3S_TOKEN=$(cat ~/.k3s_token) \
    sh -s - server --cluster-init \
    --node-ip=192.168.2.120 \
    --advertise-address=192.168.2.120 \
    --tls-san=r0.wg0.wan.buetow.org
```

`--node-ip` and `--advertise-address` bind etcd to the WireGuard interface so all control-plane traffic is encrypted.

### Join remaining nodes (r1, r2)

```sh
[root@r1 ~]# curl -sfL https://get.k3s.io | K3S_TOKEN=$(cat ~/.k3s_token) \
    sh -s - server --server https://r0.wg0.wan.buetow.org:6443 \
    --node-ip=192.168.2.121 \
    --advertise-address=192.168.2.121 \
    --tls-san=r1.wg0.wan.buetow.org

[root@r2 ~]# curl -sfL https://get.k3s.io | K3S_TOKEN=$(cat ~/.k3s_token) \
    sh -s - server --server https://r0.wg0.wan.buetow.org:6443 \
    --node-ip=192.168.2.122 \
    --advertise-address=192.168.2.122 \
    --tls-san=r2.wg0.wan.buetow.org
```

### Verify cluster

```sh
kubectl get nodes
# Expected: r0, r1, r2 all Ready with role control-plane,etcd,master
```

## kubeconfig

```sh
# Copy from any r node to laptop
scp root@r0.lan.buetow.org:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Edit: replace server address with r0.lan.buetow.org
# (repeat with r1 or r2 if r0 is down)
```

## k3s config.yaml — expose etcd and controller-manager metrics

For Prometheus to scrape etcd and controller-manager metrics, add to `/etc/rancher/k3s/config.yaml` on each r node:

```sh
cat >> /etc/rancher/k3s/config.yaml << 'EOF'
kube-controller-manager-arg:
  - bind-address=0.0.0.0
etcd-expose-metrics: true
EOF
systemctl restart k3s
```

Verify: `curl -s http://127.0.0.1:2381/metrics | grep etcd_server_has_leader`

## Built-in Components

| Component | Purpose |
|-----------|---------|
| CoreDNS | DNS for pods |
| Traefik | Ingress controller |
| local-path-provisioner | Local PVC storage |
| metrics-server | Resource metrics |
| svclb-traefik | ServiceLB for Traefik |

### Scale Traefik to 2 replicas (faster failover)

```sh
kubectl -n kube-system scale deployment traefik --replicas=2
```

## NFS Persistent Volumes

Persistent volumes use `hostPath` pointing to NFS-mounted paths:

```
/data/nfs/k3svolumes/<app>/
```

NFS is mounted on all r nodes at `/data/nfs/k3svolumes` via stunnel → CARP VIP →
freeBSD NFS — see [storage/nfs.md](../../f3s-storage/references/nfs.md). The
[`nfs-mount-monitor`](../../f3s-storage/references/nfs-mount-monitor.md) watchdog auto-repairs
hung mounts and force-deletes stuck pods.

Example PV:

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /data/nfs/k3svolumes/example-volume
    type: Directory
```

Create the directory on the NFS share before deploying: `mkdir /data/nfs/k3svolumes/<app>/`

## Deployment: GitOps with ArgoCD

Config repository: `https://codeberg.org/snonux/conf` (directory: `f3s/`)

ArgoCD app structure:
```
argocd-apps/
  monitoring/    # Prometheus, Grafana, Loki, etc.
  services/      # User-facing services
  infra/         # Infrastructure components
  test/          # Test deployments
```

**To view pre-ArgoCD state** (how things were in Part 7):
```sh
git clone https://codeberg.org/snonux/conf.git
cd conf && git checkout 15a86f3  # last commit before ArgoCD migration
cd f3s/
```

## Node IP Summary

| Node | LAN IP | WireGuard IP | k3s API |
|------|--------|-------------|---------|
| r0 | 192.168.1.120 | 192.168.2.120 | r0.wg0.wan.buetow.org:6443 |
| r1 | 192.168.1.121 | 192.168.2.121 | r1.wg0.wan.buetow.org:6443 |
| r2 | 192.168.1.122 | 192.168.2.122 | r2.wg0.wan.buetow.org:6443 |

## Useful Commands

```sh
kubectl get nodes                    # cluster status
kubectl get pods --all-namespaces    # all running pods
kubectl get namespaces
kubectl config set-context --current --namespace=<ns>
```
