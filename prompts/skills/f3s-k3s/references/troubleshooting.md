# k3s Troubleshooting

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

## Cluster-wide NFS Outages

If NFS goes down cluster-wide, the root cause is usually on the FreeBSD NFS
server side (f0/f1). Check CARP state, stunnel, nfsd, and
`vfs.nfsd.nfs_privport` — see [storage/troubleshooting.md](../../f3s-storage/references/troubleshooting.md).

## High CPU Temperature on an f-host (FreebsdCpuTemperatureHigh)

**Symptom**: Gogios/Prometheus fires `FreebsdCpuTemperatureHigh` for f0/f1/f2
(e.g. "CPU temperature high on f0 (92C)").

Each f-host runs one r-node (r0/r1/r2) as a bhyve VM, so heavy k3s workload on
that r-node directly loads the physical f-host's CPU. Check in this order:

1. **Rack fans first.** Confirm the Shelly plug is actually on —
   `f3sctl fans status` (see [shelly-plug.md](../../f3s/references/shelly-plug.md)).
   If it's off, that's the root cause; switch it on (`f3sctl fans on`) before
   touching workload placement.
2. **If fans are already on**, rebalance k3s workload off the hot node's
   r-VM. Check current usage: `kubectl top nodes` and `kubectl top pods -A
   --sort-by=memory` / `--sort-by=cpu` to find what's actually driving load
   on the affected r-node.

**Storage caveat before moving anything**: most PVs in this cluster are
`hostPath` pointing at `/data/nfs/k3svolumes/...` — an NFS export mounted
identically on r0/r1/r2, so those pods reschedule freely with no data
migration needed. Only PVs provisioned via the real `local-path`
StorageClass (`WaitForFirstConsumer`) are node-pinned — check with:

```sh
kubectl get pv -o custom-columns=NAME:.metadata.name,SC:.spec.storageClassName,PATH:.spec.hostPath.path
```

A PV with `STORAGECLASS` set (not `<unset>`) and no `.spec.hostPath` field is
genuinely node-local; leave those in place unless you're prepared to migrate
data. As of 2026-08-14 that's `storage-tempo-0` (monitoring) and
`navidrome-data-pvc` (services), both pinned to r1.

**Manual rebalance procedure** (moves pods off the hot node, e.g. r0):

```sh
kubectl --context wg0 cordon r0.lan.buetow.org
kubectl --context wg0 delete pod -n <ns> <heavy-pod-name>   # repeat for each heavy pod
kubectl --context wg0 rollout status deployment/<name> -n <ns> --timeout=180s
kubectl --context wg0 uncordon r0.lan.buetow.org
```

Deleting a pod while its node is cordoned forces the scheduler to place the
replacement on one of the remaining nodes; uncordon afterward so the node can
take normal scheduling load again. `kubectl top nodes` should show the hot
node's CPU/memory drop accordingly. This is a stopgap, not a fix — the
scheduler has nothing to balance on because most workloads (Prometheus,
Forgejo, git-server, etc.) don't set CPU/memory `requests`, so nothing
prevents them drifting back onto the same node over time. A durable fix
would set realistic requests (and/or podAntiAffinity) on the heaviest
deployments/statefulsets.
