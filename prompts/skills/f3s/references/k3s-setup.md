# k3s Setup

3-node HA k3s cluster running on the Rocky Linux VMs r0/r1/r2 (one per
FreeBSD bhyve host f0/f1/f2). All control-plane and etcd traffic flows
over WireGuard.

## Sub-references

- [Install](k3s-setup/install.md) — bootstrap, kubeconfig, etcd/controller-manager metrics, built-in components, NFS PV pattern, ArgoCD, node IP summary, useful commands
- [Remote access (off-LAN)](k3s-setup/remote-access.md) — reaching the cluster while roaming: **preferred** dedicated `wg0` kubectl context talking directly to `r0.wg0.wan.buetow.org:6443` over WireGuard (switch with `kubectl config use-context wg0`); fallback jump via OpenBSD frontend (`ssh -A rex@fishfinger.buetow.org` → `ssh root@r0.wg0` → `kubectl`), one-shot commands, and SSH port-forward tunnel
- [Ingress](k3s-setup/ingress.md) — OpenBSD `relayd` (internet) and FreeBSD `relayd` on CARP VIP (LAN), cert-manager wildcard, ingress pattern
- [Troubleshooting](k3s-setup/troubleshooting.md) — etcd Raft log corruption recovery; cluster-wide NFS outage pointer
