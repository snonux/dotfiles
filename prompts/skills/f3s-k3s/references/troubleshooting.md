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
