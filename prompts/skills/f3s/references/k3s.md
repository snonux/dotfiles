# f3s k3s Cluster (area index)

3-node HA k3s cluster running on the Rocky Linux VMs r0/r1/r2 (one per
FreeBSD bhyve host f0/f1/f2). All control-plane and etcd traffic flows
over WireGuard.

## When to Use

- Installing, bootstrapping, or recovering the k3s cluster (etcd, kubeconfig, PVs, ArgoCD)
- Reaching the cluster off-LAN, or deploying to r0/r1/r2 (incl. the gonf r-node rollout)
- Ingress/cert-manager work on the cluster
- For the underlying Rocky VMs, WireGuard mesh, storage/NFS, and host/IP inventory, see [bhyve VMs](vms.md), [Network](network.md), [Storage](storage.md) and the [hub](../SKILL.md).

## Topic Files

- [Install](k3s/install.md) — bootstrap, kubeconfig, gonf-managed `config.yaml`/`registries.yaml`, etcd/controller-manager metrics, built-in components, NFS PV pattern, ArgoCD, upgrading k3s, node IP summary, useful commands, why firewalld is off on r0–r2
- [Remote access (off-LAN)](k3s/kubectl-remote-access.md) — reaching the cluster while roaming: **preferred** dedicated `wg0` kubectl context talking directly to `r0.wg0.wan.buetow.org:6443` over WireGuard (switch with `kubectl config use-context wg0`); fallback jump via OpenBSD frontend (`ssh -A rex@fishfinger.buetow.org` → `ssh root@r0.wg0` → `kubectl`), one-shot commands, and SSH port-forward tunnel
- [Ingress](k3s/ingress.md) — OpenBSD `relayd` (internet) and FreeBSD `relayd` on CARP VIP (LAN), cert-manager wildcard, ingress pattern
- [Troubleshooting](k3s/cluster-troubleshooting.md) — etcd Raft log corruption recovery; cluster-wide NFS outage pointer; high CPU temp on an f-host (manual r-node workload rebalance)
- [r-node Deploy (gonf)](k3s/r-node-deploy.md) — reusable gonf rollout to r0/r1/r2 (`./gonf.sh cluster rocky-k3s rnodes_nfs_mount_monitor`, recipe `gonf/rnodes/maintenance.go`): root SSH, parallel 3, idempotent `InstallFile` + change-gated daemon-reload/timer restart

## Related Areas

- What is deployed on the cluster: [Workloads](workloads.md), [Observability](observability.md), [Package repo](pkgrepo.md)
