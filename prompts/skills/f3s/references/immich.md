# Immich

Immich runs in the `services` namespace. Config is in `f3s/immich/`.

## Components

- `immich-server` — main API and web UI (port 2283)
- `immich-machine-learning` — ML inference for face detection, smart search, OCR (port 3003)
- `immich-postgres` — PostgreSQL 16 with pgvecto-rs extension
- `immich-valkey` — Redis-compatible queue backend (BullMQ)

## Gathering Job Queue Stats

Immich uses BullMQ via Valkey. To snapshot current queue counters:

```sh
kubectl exec -n services deploy/immich-valkey -- sh -c '
for queue in thumbnailGeneration metadataExtraction videoConversion faceDetection smartSearch duplicateDetection backgroundTask storageTemplateMigration search sidecar library notification ocr migration; do
  waiting=$(valkey-cli LLEN "immich_bull:${queue}:wait" 2>/dev/null)
  active=$(valkey-cli LLEN "immich_bull:${queue}:active" 2>/dev/null)
  delayed=$(valkey-cli ZCARD "immich_bull:${queue}:delayed" 2>/dev/null)
  completed=$(valkey-cli ZCARD "immich_bull:${queue}:completed" 2>/dev/null)
  failed=$(valkey-cli ZCARD "immich_bull:${queue}:failed" 2>/dev/null)
  echo "${queue}: waiting=${waiting} active=${active} delayed=${delayed} completed=${completed} failed=${failed}"
done
'
```

## Saving and Comparing Snapshots

Save a snapshot to the conf repo (persistent, not `/tmp`):

```sh
kubectl exec -n services deploy/immich-valkey -- sh -c '...' > ~/git/conf/f3s/immich/snapshots/immich-queues-$(date +%Y%m%d-%H%M%S).txt
```

To compare a previous snapshot with current state, re-run the command and diff:

```sh
diff ~/git/conf/f3s/immich/snapshots/immich-queues-<old>.txt ~/git/conf/f3s/immich/snapshots/immich-queues-<new>.txt
```

Decreasing `waiting` and stable/zero `failed` means healthy progress.

## Job Control via API

The API key is stored at `~/.immich_paul_key`. Use it to pause/resume jobs:

```sh
API_KEY=$(cat ~/.immich_paul_key)

# Get all job statuses
kubectl exec -n services deploy/immich-server -- curl -s \
  -H "x-api-key: $API_KEY" http://localhost:2283/api/jobs

# Pause a job (e.g. faceDetection)
kubectl exec -n services deploy/immich-server -- curl -s -X PUT \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{"command":"pause","force":false}' \
  http://localhost:2283/api/jobs/faceDetection

# Resume a job
kubectl exec -n services deploy/immich-server -- curl -s -X PUT \
  -H "x-api-key: $API_KEY" -H "Content-Type: application/json" \
  -d '{"command":"resume","force":false}' \
  http://localhost:2283/api/jobs/faceDetection
```

### Throughput Optimization Strategy

On the N100 (4-core) nodes, ML jobs compete for CPU. To speed up slow queues:

1. **Pause faceDetection** (largest queue) to free CPU for OCR and smartSearch
2. Resume faceDetection once OCR and smartSearch finish
3. The anti-affinity in `values.yaml` prefers ML on a different node than both server and postgres

## Troubleshooting

- **Postgres crash loop**: Usually caused by liveness probe killing postgres during WAL recovery. Check `kubectl describe pod` for probe failures and postgres logs for "database system was interrupted while in recovery". Fix by relaxing probe timeouts/thresholds and adding resource limits.
- **Server crash loop**: Often caused by postgres being unavailable. Fix postgres first.
- **ML errors**: "Machine learning repository not been setup" is transient — resolves once the ML pod health check passes.
