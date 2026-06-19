# Navidrome: full rescan

Navidrome reflects **on-disk** paths and embedded tags after a scan.

## Same host as the music volume

If the `navidrome` binary is available and paths match the server:

```bash
navidrome scan --full --datafolder /path/to/data --musicfolder /path/to/music --cachefolder /path/to/cache -l info -n
```

Use the same `--datafolder`, `--musicfolder`, and `--cachefolder` as the running server (see process env e.g. `ND_DATAFOLDER`, `ND_MUSICFOLDER`, or deployment mounts).

## Kubernetes (exec into the pod)

Long scans can **outlive `kubectl exec`**; run **detached** inside the container so API disconnects do not kill the scan:

```bash
kubectl exec -n NAMESPACE POD -- sh -c \
  'nohup /app/navidrome scan --full --datafolder /data --musicfolder /music --cachefolder /data/cache -l info -n >> /data/scan-manual.log 2>&1 &'
```

Monitor:

```bash
kubectl exec -n NAMESPACE POD -- tail -f /data/scan-manual.log
```

**Caveat:** scanner and server share the SQLite DB; if corruption or locking appears, run scan with Navidrome stopped (deployment scaled to 0), then start again.
