---
name: f3s-k3s
description: Reference skill for the f3s k3s Kubernetes cluster, 3-node HA install on r0/r1/r2 Rocky VMs (bootstrap, kubeconfig, PVs, ArgoCD), off-LAN access (jump via OpenBSD frontend to root@r0.wg0 to kubectl), ingress (relayd, cert-manager), etcd recovery, and the reusable Rex r-node rollout. Use when installing, accessing, or troubleshooting the k3s cluster or deploying to r0/r1/r2. Part of the f3s homelab skill family (hub, [`f3s`](../f3s/SKILL.md)).
---

# f3s k3s Cluster

3-node HA k3s cluster running on the Rocky Linux VMs r0/r1/r2 (one per
FreeBSD bhyve host f0/f1/f2). All control-plane and etcd traffic flows
over WireGuard.

## When to Use

- Installing, bootstrapping, or recovering the k3s cluster (etcd, kubeconfig, PVs, ArgoCD)
- Reaching the cluster off-LAN, or deploying to r0/r1/r2 (incl. the Rex r-node rollout)
- Ingress/cert-manager work on the cluster
- For the underlying Rocky VMs, WireGuard mesh, storage/NFS, and host/IP inventory, see the [`f3s`](../f3s/SKILL.md) hub and [`f3s-storage`](../f3s-storage/SKILL.md).

## Reference Files

- [Install](references/install.md) — bootstrap, kubeconfig, etcd/controller-manager metrics, built-in components, NFS PV pattern, ArgoCD, node IP summary, useful commands
- [Remote access (off-LAN)](references/remote-access.md) — reaching the cluster while roaming: **preferred** dedicated `wg0` kubectl context talking directly to `r0.wg0.wan.buetow.org:6443` over WireGuard (switch with `kubectl config use-context wg0`); fallback jump via OpenBSD frontend (`ssh -A rex@fishfinger.buetow.org` → `ssh root@r0.wg0` → `kubectl`), one-shot commands, and SSH port-forward tunnel
- [Ingress](references/ingress.md) — OpenBSD `relayd` (internet) and FreeBSD `relayd` on CARP VIP (LAN), cert-manager wildcard, ingress pattern
- [Troubleshooting](references/troubleshooting.md) — etcd Raft log corruption recovery; cluster-wide NFS outage pointer
- [r-node Deploy (Rex)](references/r-node-deploy.md) — reusable Rex rollout to r0/r1/r2 (`f3s/r-nodes/Rexfile`, task `nfs_mount_monitor`): root SSH, `parallelism 3`, idempotent `file`/`on_change` reload
