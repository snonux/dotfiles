# k3s Setup

## Overview

3-node HA k3s cluster running on Rocky Linux VMs (r0, r1, r2). All nodes act as both control-plane and etcd members (no separate worker nodes).

- k3s version: **v1.32.6+k3s1** (as of Part 7)
- etcd mode: **embedded HA** (`--cluster-init`)
- All control-plane traffic goes over **WireGuard** (192.168.2.x IPs)

## Prerequisites

- All Rocky Linux VMs (r0, r1, r2) updated and running
- WireGuard mesh fully configured (see wireguard.md)
- NVMe disk emulation in place (see rocky-linux-vms.md) — critical for etcd performance

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

NFS is mounted on all r nodes at `/data/nfs/k3svolumes` via stunnel → CARP VIP → freeBSD NFS (see storage.md).

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

### NFS Mount Health Monitor (on r0, r1, r2)

Each Rocky Linux node runs `/usr/local/bin/check-nfs-mount.sh` via cron (every minute) to detect and fix stale/missing NFS mounts. After a successful remount, the script also **force-deletes stuck pods** on the local node (status Unknown, Pending, or ContainerCreating) so Kubernetes reschedules them with the healthy mount.

```sh
# Cron entry (on all r-nodes, as root)
* * * * * /usr/local/bin/check-nfs-mount.sh >> /var/log/nfs-mount-check.log 2>&1
```

The script:
1. Checks if `/data/nfs/k3svolumes` is a mountpoint and responsive (2s timeout)
2. If stale/missing: force-unmounts + remounts NFS
3. After successful remount: uses `kubectl` to find and delete stuck pods on this node
4. Uses a lock file (`/var/run/nfs-mount-check.lock`) to prevent concurrent runs

**Important**: If NFS goes down cluster-wide, the root cause is usually on the FreeBSD NFS server side (f0/f1). Check CARP state, stunnel, nfsd, and `vfs.nfsd.nfs_privport` (see storage.md).

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

## External Connectivity: OpenBSD relayd

Traffic flow for public access: `Internet → OpenBSD relayd (TLS, Let's Encrypt) → WireGuard → k3s Traefik :80 → Service`

### relayd.conf on blowfish/fishfinger

```
table <f3s> {
  192.168.2.120
  192.168.2.121
  192.168.2.122
}

http protocol "https" {
    tls keypair f3s.foo.zone
    # ... all f3s service TLS keypairs ...
    # Non-f3s hosts explicitly forwarded to localhost:
    match request header "Host" value "foo.zone" forward to <localhost>
    # f3s hosts have NO match rules — use relay-level failover
}

relay "https4" {
    listen on <PUBLIC_IP> port 443 tls
    protocol "https"
    forward to <f3s> port 80 check tcp      # primary
    forward to <localhost> port 8080         # fallback when f3s down
}
```

When all f3s nodes are down, relayd falls back to `localhost:8080` (OpenBSD httpd serving a "Server turned off" page).

## LAN Ingress: FreeBSD relayd on CARP VIP

For LAN access without going through internet gateways:
`LAN → CARP VIP (192.168.1.138) → FreeBSD relayd → k3s Traefik :443 → Service`

### FreeBSD relayd config (`/usr/local/etc/relayd.conf`)

```
table <k3s_nodes> { 192.168.1.120 192.168.1.121 192.168.1.122 }

relay "lan_http" {
    listen on 192.168.1.138 port 80
    forward to <k3s_nodes> port 80 check tcp
}

relay "lan_https" {
    listen on 192.168.1.138 port 443
    forward to <k3s_nodes> port 443 check tcp
}
```

Minimal `/etc/pf.conf` (PF required for relayd):

```
set skip on lo0
pass in quick
pass out quick
```

```sh
doas pkg install -y relayd
doas sysrc pf_enable=YES pflog_enable=YES relayd_enable=YES
doas service pf start && doas service pflog start && doas service relayd start
```

Run on both f0 and f1. Only CARP MASTER responds to VIP traffic.

### cert-manager for LAN TLS

LAN services use `*.f3s.lan.foo.zone` with a self-signed CA managed by cert-manager:

```sh
cd conf/f3s/cert-manager && just install
# Creates: selfsigned ClusterIssuer, CA cert, wildcard cert (f3s-lan-tls)
```

Copy secret to service namespace:
```sh
kubectl get secret f3s-lan-tls -n cert-manager -o yaml | \
    sed 's/namespace: cert-manager/namespace: services/' | \
    kubectl apply -f -
```

### LAN ingress pattern

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-lan
  namespace: services
  annotations:
    spec.ingressClassName: traefik
    traefik.ingress.kubernetes.io/router.entrypoints: web,websecure
spec:
  tls:
    - hosts:
        - myservice.f3s.lan.foo.zone
      secretName: f3s-lan-tls
  rules:
    - host: myservice.f3s.lan.foo.zone
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myservice
                port:
                  number: 8080
```

## Etcd Raft Log Corruption Recovery

**Symptom**: k3s crashes on startup with panic:
```
tocommit(XXXXXXX) is out of range [lastIndex(YYYYYYY)]
```
Caused by `kill -9` on the bhyve process mid-write (corrupts etcd WAL). k3s enters a crash loop and stops after ~2 minutes.

**Recovery procedure** (example: r1 is corrupt):

```sh
# 1. Stop k3s on the affected node
ssh root@r1.lan.buetow.org 'systemctl stop k3s'

# 2. Download etcdctl on a healthy node (not bundled with k3s)
ssh root@r0.lan.buetow.org
curl -sL https://github.com/etcd-io/etcd/releases/download/v3.5.17/etcd-v3.5.17-linux-amd64.tar.gz \
  | tar -xz -C /tmp etcd-v3.5.17-linux-amd64/etcdctl
mv /tmp/etcd-v3.5.17-linux-amd64/etcdctl /tmp/etcdctl

# 3. Find and remove the corrupt member from the cluster
ETCDCTL_API=3 /tmp/etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/client.key \
  member list
# Find the member ID for r1, then:
ETCDCTL_API=3 /tmp/etcdctl ... member remove <MEMBER_ID>

# 4. Delete the corrupted etcd data on the affected node
ssh root@r1.lan.buetow.org 'rm -rf /var/lib/rancher/k3s/server/db/etcd'

# 5. Restart k3s — it rejoins as a fresh member
ssh root@r1.lan.buetow.org 'systemctl start k3s'

# 6. Verify
kubectl get nodes  # r1 should return to Ready
```

> **Prevention**: Always use `doas vm stop rocky` and wait for clean shutdown before stopping the bhyve host. Only use `kill -9` on the bhyve process as a last resort — it can corrupt the etcd WAL.

## Useful Commands

```sh
kubectl get nodes                    # cluster status
kubectl get pods --all-namespaces    # all running pods
kubectl get namespaces
kubectl config set-context --current --namespace=<ns>
```
