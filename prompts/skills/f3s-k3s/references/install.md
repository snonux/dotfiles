# k3s Install

3-node HA k3s cluster running on Rocky Linux VMs (r0, r1, r2). All nodes act as both control-plane and etcd members (no separate worker nodes).

- k3s version: **v1.36.4+k3s1** (upgraded 2026-09-25 from v1.32.6+k3s1, see [Upgrading k3s](#upgrading-k3s); etcd 3.6.14, Traefik 3.7.8 / chart 40.1.4, containerd 2.3.4)
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

## k3s config.yaml and registries.yaml (gonf-managed)

Both files are managed by gonf (task pk2, `gonf/rnodes/k3s.go`, assets in
`f3s/r-nodes/k3s/`, per-host wg0 IP as `rnodes.K3sNode` in
`gonf/cluster/cluster.go`); edit them there, not on the node:

- `rnodes_k3s_config` -> `/etc/rancher/k3s/config.yaml`: `etcd-expose-metrics:
  true`, `kube-apiserver-arg: [event-ttl=1h]`, `kube-controller-manager-arg:
  [bind-address=0.0.0.0]` (Prometheus scrapes etcd and the controller manager),
  `node-ip` / `advertise-address` = the node's wg0 IP (192.168.2.12N).
- `rnodes_k3s_registries` -> `/etc/rancher/k3s/registries.yaml`: mirror
  `registry.lan.buetow.org:30001` -> `http://localhost:30001` (the in-cluster
  registry NodePort on the node itself).
- `rnodes_image_gc` -> `config.yaml.d/50-image-gc.yaml` (`kubelet-arg+`).

The join token stays in `/etc/systemd/system/k3s.service.env` (not gonf). gonf
never restarts k3s (the three control-plane nodes deploy in parallel; a
simultaneous restart drops etcd quorum). A change applies at the next boot or
via a manual rolling restart, one node at a time: `systemctl restart k3s`, wait
for Ready + `curl -s http://127.0.0.1:2381/metrics | grep
etcd_server_has_leader` + all pods Running, then the next node.

```sh
./gonf.sh -n cluster rocky-k3s rnodes_k3s_config rnodes_k3s_registries   # dry-run
```

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

Config repository: `https://github.com/snonux/conf` (directory: `f3s/`)

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
git clone https://github.com/snonux/conf.git
cd conf && git checkout 15a86f3  # last commit before ArgoCD migration
cd f3s/
```

## Upgrading k3s

Upgrade **one minor at a time** (k8s version-skew policy), using the latest
patch of each minor (`gh release list -R k3s-io/k3s`, or
`curl -s https://update.k3s.io/v1-release/channels`). Last done 2026-09-25:
1.32.6 -> 1.33.13+k3s2 -> 1.34.11+k3s1 -> 1.35.8+k3s1 -> 1.36.4+k3s1 (~35 min
total, all three nodes, no downtime beyond pod reschedules). Finish well before
the nightly ~23:30 f-host power-off.

1. `k3s etcd-snapshot save --name pre-upgrade-<ver>` on r0 and copy the file from
   `/var/lib/rancher/k3s/server/db/snapshots/` to
   `/data/nfs/k3svolumes/etcd-snapshots/` (chmod 600). Record `kubectl get nodes
   -o wide`, pods, `kubectl get applications -A` (ArgoCD apps live in ns `cicd`).
2. Per node (r2, r1, then r0; point kubectl at another node's API while r0
   restarts, e.g. `--server=https://r1.lan.buetow.org:6443`):
   `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`, then re-run
   the installer **with the same server args as the current ExecStart** (the
   script rewrites the unit and `k3s.service.env`; `config.yaml`,
   `config.yaml.d/` and `registries.yaml` are left alone):

   ```sh
   # r0
   curl -sfL https://get.k3s.io | K3S_TOKEN=$(cat ~/.k3s_token) INSTALL_K3S_VERSION=vX.Y.Z+k3sN \
     sh -s - server --cluster-init --tls-san=r0.wg0.wan.buetow.org
   # r1 / r2
   curl -sfL https://get.k3s.io | K3S_TOKEN=$(cat ~/.k3s_token) INSTALL_K3S_VERSION=vX.Y.Z+k3sN \
     sh -s - server --server https://r0.wg0.wan.buetow.org:6443 --tls-san=rN.wg0.wan.buetow.org
   ```

   Check `k3s --version` afterwards: once the installer exited 0 yet left the
   old binary (transient GitHub download failure); re-running fixed it. Wait for
   the node to be Ready on the new version, uncordon, and confirm etcd
   (`curl -s 127.0.0.1:2381/metrics | grep etcd_server_has_leader` on each node),
   all pods Running and all ArgoCD apps Synced/Healthy before the next node.
3. After the last node: full check, ingress probes, and remove stale
   `/var/lib/rancher/k3s/data/<hash>` dirs other than `current`/`previous`
   (~250M each).

Expected noise during a mixed-version window:
- `kube-system/helm-install-traefik-*` CrashLoopBackOff: the new bundled chart
  tgz is only served by already-upgraded apiservers (404 from old ones) and etcd
  times out while a member restarts. It completes on its own once most servers
  are upgraded.
- ArgoCD apps briefly `Unknown` (repo is the in-cluster Forgejo, which gets
  rescheduled by the drain); `kubectl -n cicd annotate application <app>
  argocd.argoproj.io/refresh=hard --overwrite` clears it.
- Public `code.f3s` / `gpodder.f3s` on 443 return nothing: blocked in relayd on
  purpose, not an upgrade issue.

Version notes: 1.33 moves etcd 3.5 -> 3.6 (needs >= 3.5.20 first; cluster
version flips to 3.6 once all members run it, so rolling back below 1.33 means
an etcd snapshot restore) and Traefik 3.3 -> 3.7 (chart 34 -> 40; our
`HelmChartConfig` only sets `additionalArguments` and `metrics.prometheus`,
both still valid). Traefik >= 3.6 rejects some encoded characters in request
paths by default (startup WRN). 1.34 drops the `node-role.kubernetes.io/master`
tolerations (nothing here selects on it). Use an etcdctl 3.6.x for the
[etcd recovery](troubleshooting.md) procedure now.

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

## Host firewall on r0/r1/r2: firewalld is off on purpose

Decided/verified 2026-09-25 (audit item 28): `firewalld` is **disabled** on the
r-nodes, as the WireGuard setup (f3s hub `references/wireguard.md`) prescribes
and as k3s recommends (firewalld's nftables rules fight kube-proxy/flannel).
Exposure is acceptable because the nodes sit on the home LAN / WireGuard mesh
only (the internet reaches workloads solely via the OpenBSD relayd frontends),
and the listeners that matter are authenticated: 6443 (API), 10250 (kubelet),
etcd 2379-2381 bound to the wg0 address. Unauthenticated but harmless on the
LAN: 9100 (node_exporter). Needless: rpcbind on 0.0.0.0:111 — the k3svolumes
mount is NFSv4 and does not need it; disabling `rpcbind.socket`/`rpcbind` is a
safe cleanup to try on one node first (confirm the mount survives a remount).
Re-enabling firewalld would need explicit rules for 6443, 10250, 2379-2381,
8472/udp (flannel VXLAN), 51820/udp (wg0), 22, 2222 (dserver), 9100.
