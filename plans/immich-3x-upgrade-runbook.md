# Immich 3.x Upgrade Runbook (f3s)

**Status:** ✅ COMPLETED on 2026-07-18. Immich was upgraded live from v2.7.5 to
**v3.0.3** on VectorChord. See the "Execution record" section below for what actually
happened and the findings that this plan (written beforehand) could not confirm.

**Task:** `7t0` — Upgrade the Immich f3s installation to 3.x.

**Date written:** 2026-07-18

---

## Execution record (2026-07-18) — what actually happened

The upgrade was carried out live, GitOps-driven, and completed successfully. Outcome:

- **server + machine-learning:** `v2.7.5` → **`v3.0.3`**
- **postgres:** `tensorchord/pgvecto-rs:pg16-v0.3.0` →
  **`ghcr.io/immich-app/postgres:16-vectorchord0.4.3-pgvector0.8.0-pgvectors0.3.0`**
  (chosen to match the installed `vectors` 0.3.0 catalog; verified to exist on ghcr
  with a `linux/amd64` manifest before use).
- **Data intact & migrated:** 87,522 assets; 78,159 + 15,139 embeddings reindexed onto
  the `vchordrq` (VectorChord) access method; old `vectors`/pgvecto.rs extension dropped.
- **Backups taken first:** ZFS snapshot `zdata/enc/nfsdata@immich-pre-3x-20260718` on f0
  (CARP MASTER) + a 287 MB `pg_dump` custom-format archive. Snapshot cleanup tracked as
  task `dv0` (due 2026-08-01).

### Findings the plan flagged `[VERIFY]` — now resolved

1. **ArgoCD lives in namespace `cicd`** (not `argocd`); the app is `immich`.
2. **The `f3s/argocd-apps/services/*.yaml` Application manifests are NOT GitOps-synced.**
   They carry `kubectl.kubernetes.io/last-applied-configuration` and have no app-of-apps /
   ApplicationSet owner, so a git change to them has no effect until `kubectl apply -f
   <file>` is run. **The Immich version pin (`image.tag`) lives in
   `f3s/argocd-apps/services/immich.yaml`** — so Stage B = edit that file, push to the
   `r0` remote, **and** `kubectl apply` it. By contrast each app's *source dir* (e.g.
   `f3s/immich/helm-chart/`, where `postgres.yaml` lives) IS ArgoCD-synced from the
   in-cluster git-server (`r0` = `ssh://git@r0:30022/repos/conf.git`) with self-heal on
   (imperative `kubectl` edits get reverted in ~20s — go through git).
3. **`shared_preload_libraries` swap is clean:** the old value came from a command-line
   arg (not persisted in PGDATA), so no stale `vectors.so`-only override fought the Immich
   image's `vchord.so, vectors.so` template. Confirmed both preloaded after the swap.
4. **Immich v2.7.5 auto-runs the VectorChord reindex** on startup once `vchord` is
   available — Stage A does not require the 3.x server (log: "Reindexing clip_index … do
   not restart").
5. **3.x removed `deviceId`/`deviceAssetId`** (migration `DropDeviceIdAndDeviceAssetId`).
   The `/api/assets` endpoint still tolerates but ignores them; `scripts/immich-upload`
   was cleaned up regardless. `scripts/immich-export` (`/api/search/metadata`,
   `/api/assets/{id}/original`) was verified unaffected.

### Commits

- conf repo (pushed to **both** `r0` and codeberg): `a536047` (Stage A), `1c67c58` (Stage B).
- dotfiles repo: `7f2d41d` (`immich-upload` 3.x fix).

---

## 0. TL;DR / critical path

Going straight from the current install to Immich 3.x **will fail**, because 3.0
**drops pgvecto.rs support** and this deployment's Postgres still uses the
`tensorchord/pgvecto-rs` image. The upgrade is therefore a **two-stage** job:

1. **Stage A (while still on Immich 2.x):** migrate the database off pgvecto.rs
   onto **VectorChord**, by swapping the Postgres image to the Immich-provided
   bundle image that auto-migrates on startup. This is a **one-way door** — after
   it, Immich must never be downgraded below v1.133.0.
2. **Stage B:** bump the Immich server + machine-learning image tags from `v2.7.5`
   to the target `v3.x` tag.

Mandatory before either stage: a **ZFS snapshot** of the dataset backing all Immich
volumes **plus** a **logical `pg_dump`** of the database.

Sources for the breaking-change claims are cited inline in §3.

---

## 1. Current state (as deployed today)

All Immich manifests live in the **conf** repo (`https://codeberg.org/snonux/conf`,
locally `~/git/conf`), deployed via **ArgoCD**. Immich runs in the `services`
namespace on the 3-node k3s cluster (r0/r1/r2).

| Component | Version / image | Source file |
|-----------|-----------------|-------------|
| Immich server | image tag **`v2.7.5`** | `~/git/conf/f3s/argocd-apps/services/immich.yaml` (helm inline values, `server.controllers.main.containers.main.image.tag`) |
| Immich machine-learning | image tag **`v2.7.5`** | same file (`machine-learning.controllers.main.containers.main.image.tag`) |
| Upstream Helm chart | `immich` chart **`0.10.3`** from `https://immich-app.github.io/immich-charts/` | same file (`spec.sources[1].targetRevision`) |
| PostgreSQL | **`tensorchord/pgvecto-rs:pg16-v0.3.0`** (PG16 + pgvecto.rs) | `~/git/conf/f3s/immich/helm-chart/templates/postgres.yaml` |
| Valkey (BullMQ queue) | from upstream chart, `valkey.enabled: true` | `~/git/conf/f3s/argocd-apps/services/immich.yaml` |
| Custom-resources chart | local chart `immich-resources` v0.1.0, `appVersion: "2.0.0"` (this is NOT the Immich version — it is the local wrapper chart) | `~/git/conf/f3s/immich/helm-chart/Chart.yaml` |

**Deployment model.** The ArgoCD `Application` (`f3s/argocd-apps/services/immich.yaml`)
has two `sources`:

- `f3s/immich/helm-chart` — local chart providing the **PVs/PVCs**, the **custom
  Postgres Deployment** (`postgres.yaml`), Traefik body-size middleware
  (`middleware.yaml`), and the LAN ingress (`ingress-lan.yaml`).
- the upstream `immich` Helm chart `0.10.3` with a large inline `helm.values` block
  (server, machine-learning, valkey, ingress `immich.f3s.buetow.org`).

`syncPolicy.automated.selfHeal: true`, `prune: false`. **Implication:** editing the
tracked manifests and letting ArgoCD self-heal is the normal apply path; but because
Postgres is a *hand-rolled Deployment* (not managed by the upstream chart), the DB
image swap in Stage A is a change to `postgres.yaml`, and reindex timing must be
watched manually.

**Storage (this is what the ZFS snapshot must capture).** All Immich PVs are
`hostPath` volumes under `/data/nfs/k3svolumes/immich/`
(`f3s/immich/helm-chart/templates/persistent-volume.yaml`):

| PVC | hostPath | Size |
|-----|----------|------|
| `immich-postgres-pvc` | `/data/nfs/k3svolumes/immich/postgres` | 20Gi |
| `immich-library-pvc` | `/data/nfs/k3svolumes/immich/library` | 500Gi |
| `immich-valkey-pvc` | `/data/nfs/k3svolumes/immich/valkey` | 1Gi |
| `immich-ml-cache-pvc` | `/data/nfs/k3svolumes/immich/ml-cache` | 10Gi |
| `immich-ext-albena-pvc` | `/data/nfs/k3svolumes/immich/external-library/albena` | 200Gi |
| `immich-ext-paul-pvc` | `/data/nfs/k3svolumes/immich/external-library/paul` | 200Gi |
| `immich-ext-videos-rw-pvc` / `-ro-pvc` | `/data/nfs/k3svolumes/immich/external-library/videos` | 500Gi |

On the r-nodes `/data/nfs/k3svolumes` is an **NFS mount** (`127.0.0.1:/k3svolumes`
over stunnel → CARP VIP `192.168.1.138:2323`). The NFS server is a **FreeBSD f-host
(f0, or f1 after a CARP failover)**, and the export is served from the single ZFS
dataset **`zdata/enc/nfsdata`** (mountpoint `/data/nfs`), which is `zrepl`-replicated
`f0 → f1` every minute (snapshot prefix `zrepl_`).

**Key fact for backups:** `k3svolumes/immich/*` are ordinary subdirectories inside
the one dataset `zdata/enc/nfsdata` — they are **not** separate child ZFS datasets.
So a **single** `zfs snapshot zdata/enc/nfsdata@...` captures **all** Immich state
(Postgres data dir + library + valkey + external libraries) **atomically**. That is
exactly what we want.

---

## 2. Pre-flight / backups (MANDATORY — do all of this before Stage A)

Do these in order. The **ZFS snapshot is the primary rollback mechanism**; the
logical `pg_dump` is the secondary, portable safety net (and the only thing that
survives a dataset-level disaster).

### 2.0 Preconditions to check first

```sh
# From a machine with kubectl access to the cluster (e.g. earth via the jump host).
kubectl get pods -n services | grep immich          # note current healthy state
kubectl get pvc  -n services | grep immich          # all Bound
# Confirm current image tags actually running:
kubectl get deploy -n services immich-server -o jsonpath='{..image}{"\n"}'
kubectl get deploy -n services immich-postgres -o jsonpath='{..image}{"\n"}'
```

Determine **which f-host is the CARP MASTER** (that host owns `/data/nfs` read-write
and is where the snapshot must be taken). On f0/f1:

```sh
# On f0 and f1 (FreeBSD):
ifconfig | grep -A2 carp        # MASTER vs BACKUP
zfs list zdata/enc/nfsdata      # confirms this host currently holds the RW dataset
mount | grep /data/nfs
```

The snapshot must be taken on the **MASTER** (normally **f0**). Taking it on the
read-only zrepl replica (f1's `zdata/sink/...`) would only capture whatever the last
1-minute replication pushed, not a quiesced state.

### 2.1 Quiesce Immich (recommended for a clean, restorable snapshot)

A ZFS snapshot is crash-consistent, and Postgres can recover from a crash-consistent
copy — but a **quiesced** snapshot is cleaner and avoids WAL-replay surprises during
an already-risky migration. Scale Immich down (leave Postgres up for the logical dump
in 2.2, then stop it too for the snapshot in 2.3):

```sh
# Stop the app tier so nothing writes to the library/DB during backup.
kubectl scale deploy -n services immich-server --replicas=0
kubectl scale deploy -n services immich-machine-learning --replicas=0
# Valkey holds only the transient job queue; scaling it to 0 is optional but tidy:
kubectl scale deploy -n services immich-valkey --replicas=0    # if it is a Deployment; check kind first
```

(If any component is a `StatefulSet` rather than a `Deployment`, scale the correct
kind — verify with `kubectl get deploy,sts -n services | grep immich`.)

### 2.2 Logical database backup (`pg_dump`) — secondary backup

Take this **while Postgres is still on the pgvecto.rs image** so the dump is
restorable onto that same image if we abort before Stage A.

```sh
# Dump into the DB pod, then copy out. Adjust user/db (immich/immich).
TS=$(date +%Y%m%d-%H%M%S)
kubectl exec -n services deploy/immich-postgres -- \
  sh -c 'pg_dumpall --clean --if-exists -U immich' > ~/immich-db-pgdumpall-$TS.sql

# Verify the dump is non-empty and contains the immich schema + a table count.
ls -lh ~/immich-db-pgdumpall-$TS.sql
grep -c 'CREATE TABLE' ~/immich-db-pgdumpall-$TS.sql          # expect > 0 (dozens)
tail -n 5 ~/immich-db-pgdumpall-$TS.sql                       # should end cleanly, no truncation
```

Notes:
- `pg_dumpall` needs **superuser** — the `immich` role is the DB owner/superuser in
  this single-role deployment, so this works. Immich's own docs recommend
  `pg_dumpall` for full backups.
- **This logical dump does NOT include the photo/video files** — those live in the
  `library`/`external-library` directories and are covered by the ZFS snapshot (2.3).
- Store a copy off the cluster (e.g. onto `earth`, and ideally the S3 Glacier
  off-site backup used elsewhere in f3s).

### 2.3 ZFS snapshot — PRIMARY backup

Run on the CARP **MASTER** f-host (normally f0). One atomic snapshot of the whole
dataset captures Postgres + library + valkey + external libraries together.

Naming convention: use a **non-`zrepl_` prefix** so the zrepl pruner (whose keep
rules match `regex: "^zrepl_.*"`) will **not** auto-destroy it. Suggested:
`immich-pre-3x-<YYYYMMDD>`.

```sh
# On the CARP MASTER (f0), as a user that can run doas:
SNAP="immich-pre-3x-$(date +%Y%m%d)"

# Optional but ideal: take it AFTER scaling Immich (incl. Postgres) to 0 so the
# on-disk state is quiesced. To also stop Postgres for a fully clean snapshot:
#   kubectl scale deploy -n services immich-postgres --replicas=0
#   (wait for the pod to terminate, confirm no writer holds the data dir)

doas zfs snapshot zdata/enc/nfsdata@${SNAP}

# VERIFY the snapshot exists and note its creation time / referenced size:
doas zfs list -t snapshot -o name,creation,referenced zdata/enc/nfsdata | grep "${SNAP}"

# Spot-check the snapshot is browsable and contains the immich dirs (read-only):
ls /data/nfs/.zfs/snapshot/${SNAP}/k3svolumes/immich/
ls /data/nfs/.zfs/snapshot/${SNAP}/k3svolumes/immich/postgres/    # PG data dir present
```

Because zrepl runs every minute, this manual snapshot will also replicate to f1 on
the next cycle, giving an **off-host copy** as well. Confirm:

```sh
# On f1 (BACKUP / sink):
doas zfs list -t snapshot | grep "${SNAP}"   # appears on zdata/sink/f0/zdata/enc/nfsdata after replication
```

**Do not** name any manual snapshot with the `zrepl_` prefix, and **do not** run
`zfs-periodic`/`zfs rollback` on zrepl-managed datasets casually — zrepl owns the
`zrepl_*` snapshot lifecycle on this dataset (see the f3s storage/zrepl reference).

### 2.4 Restart Immich to its current healthy state before starting Stage A

If you scaled things down for the snapshot and want to confirm the app still comes
up on the *old* stack before changing anything:

```sh
kubectl scale deploy -n services immich-postgres --replicas=1   # if you stopped it
kubectl scale deploy -n services immich-valkey --replicas=1
kubectl scale deploy -n services immich-server --replicas=1
kubectl scale deploy -n services immich-machine-learning --replicas=1
kubectl get pods -n services | grep immich                       # all Running/Ready
```

At this point you have: a verified ZFS snapshot (primary), a verified `pg_dumpall`
(secondary, off-cluster), and a known-good running v2.7.5 install. Proceed.

---

## 3. Breaking changes for 3.x (with sources)

All of the following are from Immich's official release notes / docs. Where I could
not fully verify a detail against this specific deployment, it is flagged
**[VERIFY]**.

### 3.1 pgvecto.rs is removed — must migrate to VectorChord first (CONFIRMED, highest impact)

- v3.0.0 includes `chore(server)!: drop pgvecto.rs support`. Installs still on
  pgvecto.rs must migrate to **VectorChord** *before* upgrading to 3.x.
  Source: [Immich v3.0.0 release blog](https://immich.app/blog/v3.0.0-release),
  [v3.0.0 GitHub release](https://github.com/immich-app/immich/releases/tag/v3.0.0).
- The VectorChord migration was introduced in **v1.133.0**; the current install
  (`v2.7.5`) is well past that, so it is eligible to run the migration.
  Source: [v1.133.0 discussion #18429](https://github.com/immich-app/immich/discussions/18429).
- **This deployment is directly affected** — Postgres is `tensorchord/pgvecto-rs:pg16-v0.3.0`.
- **One-way door:** *"After switching to VectorChord, you should not downgrade Immich
  below 1.133.0."* Source: [Upgrading | Immich](https://docs.immich.app/install/upgrading/).

### 3.2 The migration is done by swapping to the Immich Postgres bundle image (CONFIRMED)

- Immich publishes `ghcr.io/immich-app/postgres`, a bundle image that ships
  **VectorChord + pgvector + pgvecto.rs** together, so it can read an existing
  pgvecto.rs database and **auto-migrate** it to VectorChord on startup.
  Source: [discussion #18429](https://github.com/immich-app/immich/discussions/18429),
  [Upgrading | Immich](https://docs.immich.app/install/upgrading/).
- The **transitional tag must be one that still bundles pgvecto.rs**, i.e. of the
  form `16-vectorchord<X.Y.Z>-pgvectors0.2.0` (docs show examples like
  `14-vectorchord0.4.3-pgvectors0.2.0` and `16-vectorchord0.3.0-pgvectors0.2.0`).
  **[VERIFY the exact newest PG16 `...-pgvectors0.2.0` tag at execution time]** — the
  GHCR package listing currently also shows newer **vchord-only** tags such as
  `16-vectorchord1.1.1-pgvector0.8.5` that **do NOT bundle pgvecto.rs** and therefore
  **cannot** auto-migrate a pgvecto.rs DB. Migrate with a `-pgvectors0.2.0` tag first;
  only move to a vchord-only tag *after* the migration completes.
  Source: [ghcr.io/immich-app/postgres tags](https://github.com/immich-app/immich/pkgs/container/postgres).
- Keep **PostgreSQL major version 16 → 16** across the swap (both the old
  `pgvecto-rs:pg16` and the new `16-vectorchord...` images are PG16), so the on-disk
  data directory is compatible and no `pg_upgrade` is needed.

### 3.3 PostgreSQL / extension version support (CONFIRMED)

- Immich supports **Postgres `>= 14, < 20`** — PG16 is fine.
- Requires **pgvector `>= 0.7, < 0.9`** and the **`vchord`** extension (VectorChord);
  `earthdistance` is created via `CREATE EXTENSION vchord CASCADE`.
  Source: [Pre-existing/standalone Postgres | Immich](https://docs.immich.app/administration/postgres-standalone/).

### 3.4 Machine-learning: numpy 2.4 → requires x86-64-v2 CPU (CONFIRMED, not a problem here)

- v3.0.0 bumps numpy (`chore(ml)!: require numpy 2.4`); x86 CPUs must be
  **x86-64-v2** microarchitecture level or higher (AVX not required).
  Source: [v3.0.0 blog](https://immich.app/blog/v3.0.0-release).
- The f3s nodes are **Intel N100 (Alder Lake-N / Gracemont, 2023)**, which is well
  above x86-64-v2. **No action needed**, but worth stating explicitly.

### 3.5 Removed deprecated environment variables (CONFIRMED that some were removed; exact list [VERIFY])

- v3.0.0 includes `chore!: remove deprecated env variables` and
  `chore(ml)!: remove deprecated envs`. Source: [v3.0.0 blog](https://immich.app/blog/v3.0.0-release).
- **[VERIFY]** none of the env vars this deployment sets are on the removed list. The
  vars currently set (in `immich.yaml` / `postgres.yaml`) are:
  `DB_HOSTNAME`, `DB_DATABASE_NAME`, `DB_USERNAME`, `DB_PASSWORD`,
  `MACHINE_LEARNING_MODEL_INTRA_OP_THREADS`, `MACHINE_LEARNING_MODEL_INTER_OP_THREADS`,
  `MACHINE_LEARNING_WORKER_TIMEOUT`. These are all still-standard in recent Immich,
  but confirm against the 3.0 breaking-change changelog before applying.

### 3.6 API endpoint removals / changes (CONFIRMED at a high level; per-endpoint [VERIFY])

- v3.0.0 removes/changes several API endpoints: `getRandom` removed,
  `/api/server/theme` removed, old timeline-sync endpoints removed, `deviceId` /
  `deviceAssetId` parameters removed, and asset **duration is now in milliseconds**.
  Source: [v3.0.0 blog](https://immich.app/blog/v3.0.0-release).
- **Local tooling that uses the API** lives in this repo:
  `~/git/dotfiles/scripts/immich-upload` and `~/git/dotfiles/scripts/immich-export`.
  Endpoints they call: `/api/server/ping`, `/api/assets`, `/api/assets/bulk-upload-check`,
  `/api/search/metadata`. None of those are in the *removed* list above, **but**
  `immich-upload` builds a multipart asset upload that historically included
  `deviceAssetId` / `deviceId` form fields — **[VERIFY]** whether removing those
  params breaks `POST /api/assets`, and update the script if so. Also review
  `immich-export`'s reliance on any `duration` field (now milliseconds).

### 3.7 "Most breaking changes are API-only" (context)

- Immich states most 3.0 breaking changes affect third-party API integrations, and
  for the majority of users upgrading "works exactly as it always has" (once off
  pgvecto.rs). Source: [v3.0.0 blog](https://immich.app/blog/v3.0.0-release).

### 3.8 Known post-migration failure mode (WATCH)

- There are reports of v3 failing after a pgvecto.rs → VectorChord migration when the
  DB still contains `vectors.vector(512)` columns / a leftover `vectors` schema (i.e.
  the auto-migration/reindex did not fully complete before the 3.x bump).
  Source: [issue #29983](https://github.com/immich-app/immich/issues/29983).
- **Mitigation:** in Stage A, wait for the reindex log lines and confirm the old
  `vectors` extension/schema is gone **before** starting Stage B (see §4.2 step 6).

---

## 4. Step-by-step upgrade procedure

> Prerequisite: §2 fully done and verified (ZFS snapshot + `pg_dumpall`, both
> confirmed), and the app is currently healthy on v2.7.5.

### 4.1 Pin exact target versions before touching anything

Decide and record, at execution time:
- **Target Immich app version:** the specific `v3.x.y` tag (start with the latest
  stable `v3` patch). Used for both server and machine-learning image tags.
- **Transitional Postgres image:** newest **PG16 VectorChord tag that still bundles
  pgvecto.rs**, i.e. `ghcr.io/immich-app/postgres:16-vectorchord<X.Y.Z>-pgvectors0.2.0`
  (see §3.2 — do NOT pick a vchord-only tag for the migration step).
- **[VERIFY]** whether the upstream `immich` Helm chart `0.10.3` supports the v3
  image tag cleanly, or whether the chart needs a bump too. Chart and app versions
  are independent; a newer chart may be required for v3 defaults. Check the
  [immich-charts releases](https://github.com/immich-app/immich-charts) and bump
  `spec.sources[1].targetRevision` in `immich.yaml` if needed.

### 4.2 Stage A — migrate Postgres pgvecto.rs → VectorChord (STILL on Immich v2.7.5)

Keep the Immich server/ML on `v2.7.5` throughout Stage A. Only the **Postgres image**
changes here.

1. Edit `~/git/conf/f3s/immich/helm-chart/templates/postgres.yaml`:
   change the container image from
   `tensorchord/pgvecto-rs:pg16-v0.3.0`
   to the chosen `ghcr.io/immich-app/postgres:16-vectorchord<X.Y.Z>-pgvectors0.2.0`.
   - **Review the liveness/readiness probes and initContainer.** The current probes
     assume the pgvecto.rs image layout (`pg_isready` + `pg_filenode.map` check) and
     an NFS sentinel init check — these should still work on the Immich Postgres image
     (same PG16 data dir), but **[VERIFY]** the new image doesn't expect extra
     `shared_preload_libraries` command args. The Immich image sets up
     `shared_preload_libraries` for VectorChord itself, so **do not** override the
     Postgres command in a way that drops it. Keep the Deployment `strategy: Recreate`.
   - Update the code comment in `postgres.yaml` (the header currently says
     "Requires PostgreSQL 16+ with pgvector extension") to reflect VectorChord.
2. Commit to the `conf` repo and let ArgoCD sync (or `kubectl apply -f` the template).
   Because Postgres is `Recreate`, the old pod terminates before the new one starts —
   good (avoids two writers on the NFS-backed data dir).
3. Watch the Postgres pod come up on the new image:
   ```sh
   kubectl get pods -n services | grep immich-postgres
   kubectl logs -n services deploy/immich-postgres -f
   ```
4. Bring the Immich server back (if it was scaled down) and watch **its** logs — the
   auto-migration/reindex is driven by Immich on startup:
   ```sh
   kubectl logs -n services deploy/immich-server -f
   ```
   Wait for reindex completion log lines (e.g. `Reindexed face_index` /
   `Reindexed clip_index`, or `Reindexing ...` finishing). This can take
   **minutes on the N100 for a large library** — do not interrupt.
5. Confirm the app is fully healthy on v2.7.5 + VectorChord: web UI loads at
   `https://immich.f3s.buetow.org`, photos/thumbnails render, smart search and face
   search work.
6. **Confirm the old vector extension is gone (guards against §3.8):**
   ```sh
   kubectl exec -n services deploy/immich-postgres -- \
     psql -U immich -d immich -c "\dx"                      # expect: vchord, vector; NOT vectors
   kubectl exec -n services deploy/immich-postgres -- \
     psql -U immich -d immich -c "\dn"                      # 'vectors' schema should be gone
   kubectl exec -n services deploy/immich-postgres -- \
     psql -U immich -d immich -c \
     "SELECT column_name, udt_name FROM information_schema.columns WHERE udt_name LIKE '%vector%';"
   ```
   If a leftover `vectors` schema/extension remains, follow the
   [standalone Postgres migration doc](https://docs.immich.app/administration/postgres-standalone/)
   to `DROP EXTENSION vectors;` / `DROP SCHEMA vectors;` **before** proceeding.
7. **Checkpoint:** take a *second* ZFS snapshot now
   (`zdata/enc/nfsdata@immich-post-vchord-<YYYYMMDD>`) and optionally a fresh
   `pg_dumpall`. This gives a clean rollback point that is already on VectorChord, so
   a Stage B failure does not force redoing the whole migration.
   Note: a `pg_dumpall` taken *after* switching to VectorChord can only be restored
   onto an image that contains VectorChord (per Immich docs).

### 4.3 Stage B — bump Immich to 3.x

1. Edit `~/git/conf/f3s/argocd-apps/services/immich.yaml`:
   - `server.controllers.main.containers.main.image.tag`: `v2.7.5` → `v3.x.y`
   - `machine-learning.controllers.main.containers.main.image.tag`: `v2.7.5` → `v3.x.y`
   - if §4.1 determined a chart bump is needed, update
     `spec.sources[1].targetRevision` (`0.10.3` → chosen chart version).
   - remove/rename any env vars flagged in §3.5 **[VERIFY]**.
2. Commit to `conf`; let ArgoCD sync (`selfHeal: true` will pick it up, or force with
   the `just sync` recipe in `f3s/immich/Justfile`).
3. Watch the rollout:
   ```sh
   kubectl rollout status -n services deploy/immich-server --timeout=300s
   kubectl rollout status -n services deploy/immich-machine-learning --timeout=300s
   kubectl logs -n services deploy/immich-server -f      # watch for v3 startup DB migrations
   ```
   Immich runs schema migrations on first v3 startup; allow seconds–minutes.

---

## 5. Verification (post-upgrade)

```sh
# 1. Pods healthy on the new tags.
kubectl get pods -n services | grep immich                 # all Running/Ready
kubectl get deploy -n services immich-server -o jsonpath='{..image}{"\n"}'   # v3.x.y
kubectl get deploy -n services immich-machine-learning -o jsonpath='{..image}{"\n"}'

# 2. Server reports the new version and DB migrations completed (no errors in logs).
kubectl logs -n services deploy/immich-server --tail=100 | grep -iE 'version|migrat|error'

# 3. DB extensions correct: vchord + vector present, vectors absent.
kubectl exec -n services deploy/immich-postgres -- psql -U immich -d immich -c "\dx"

# 4. Machine learning reachable and models load (face/smart search).
kubectl logs -n services deploy/immich-machine-learning --tail=50
```

Functional checks in the web UI (`https://immich.f3s.buetow.org` /
`http://immich.f3s.lan.buetow.org`):
- Log in; timeline loads with thumbnails.
- Open a photo and a video full-size (library + external-library assets both).
- Run a **smart search** query and a **face** browse (exercises VectorChord indexes).
- Admin → check the **version** shown is v3.x, and the **job queues** page is
  reachable (BullMQ/Valkey intact).
- Trigger a small job (e.g. re-run thumbnail generation on one asset) and confirm it
  completes.

Re-test the repo's API tooling once the server is on v3 (§3.6):
`~/git/dotfiles/scripts/immich-upload` (upload one test image) and
`~/git/dotfiles/scripts/immich-export` (dry small date range). Fix any
`deviceId`/`deviceAssetId`/`duration` fallout.

Compare a job-queue snapshot against the last saved one (per the f3s Immich skill's
snapshot workflow) to confirm no queue is stuck.

---

## 6. Rollback plan

**Important caveat:** DB migrations are generally **NOT cleanly reversible**. Both the
VectorChord migration (Stage A) and the v3 schema migrations (Stage B) change the
database. **You cannot simply set the image tag back and expect a clean downgrade** —
in particular, once on VectorChord you must never run Immich < v1.133.0, and v3 schema
changes are not designed to be run backwards. This is exactly why §2 backups are
mandatory. Rollback = **restore from backup**, not "re-pin the old tag".

### 6.1 Roll back a failed Stage B (still have the §4.2.7 post-VectorChord snapshot)

Preferred if the DB is only lightly changed and you have a clean VectorChord-era
snapshot/dump:
1. Scale Immich server + ML to 0.
2. Restore the DB from the **post-VectorChord** `pg_dumpall` (§4.2.7) into a
   VectorChord-capable Postgres image, **or** roll the ZFS dataset back to the
   `immich-post-vchord-<date>` snapshot (see 6.3).
3. Re-pin server/ML tags back to `v2.7.5` in `immich.yaml`, sync, verify.

### 6.2 Full roll back to the original pgvecto.rs install (pre-everything)

Use the §2 backups (`immich-pre-3x-<date>` snapshot + the pgvecto.rs-era `pg_dumpall`):
1. Scale all Immich components to 0.
2. Restore `postgres.yaml` to `tensorchord/pgvecto-rs:pg16-v0.3.0` and revert
   `immich.yaml` server/ML tags to `v2.7.5` (git revert the relevant commits in
   `conf`).
3. Restore the data (choose one):
   - **ZFS rollback** (whole dataset, fastest, restores DB + library + everything to
     the exact pre-upgrade state) — see 6.3; **or**
   - restore only the DB from the pgvecto.rs-era `pg_dumpall` onto the restored
     pgvecto.rs image (leaves library files as-is).
4. Sync ArgoCD, verify per §5 against v2.7.5.

### 6.3 ZFS rollback mechanics (destructive — understand the trade-off)

`zfs rollback` reverts the **entire** `zdata/enc/nfsdata` dataset to the snapshot,
**discarding all changes since** — including any non-Immich data written to
`/data/nfs` after the snapshot, and any newer `zrepl_` snapshots. On a shared NFS
dataset this is a big hammer. Prefer file-level restore from the snapshot directory
when only Immich needs reverting.

```sh
# On the CARP MASTER (f0). Stop writers first (Immich scaled to 0).
# Inspect snapshots:
doas zfs list -t snapshot zdata/enc/nfsdata

# SAFEST: file-level restore of just the immich tree from the read-only snapshot dir
#   rsync -a --delete \
#     /data/nfs/.zfs/snapshot/immich-pre-3x-<date>/k3svolumes/immich/ \
#     /data/nfs/k3svolumes/immich/
# (do this with Immich scaled to 0; the DB pod must not be running)

# NUCLEAR: full dataset rollback (reverts EVERYTHING in the dataset, and destroys
# any snapshots newer than the target — including intervening zrepl_ snapshots):
#   doas zfs rollback -r zdata/enc/nfsdata@immich-pre-3x-<date>
# Because this destroys newer snapshots, it will disrupt the zrepl f0->f1 chain and
# may force a re-sync. Coordinate with the storage/zrepl runbook before doing this.
```

After any DB restore, restart Postgres, then Immich, and verify per §5.

### 6.4 Cleanup of backup snapshots (only after success is confirmed and stable)

```sh
# On f0, once the upgrade is verified healthy and you no longer need the rollback point:
doas zfs destroy zdata/enc/nfsdata@immich-pre-3x-<date>
doas zfs destroy zdata/enc/nfsdata@immich-post-vchord-<date>
# The replicated copies on f1 (zdata/sink/...) will be pruned per zrepl policy or can
# be destroyed manually if they were replicated.
```

Keep the `pg_dumpall` files until the v3 install has run cleanly for a while.

---

## 7. Risks & open questions (decide/verify before executing)

1. **[VERIFY] Exact transitional Postgres tag.** Pick the newest
   `ghcr.io/immich-app/postgres:16-vectorchord<X.Y.Z>-pgvectors0.2.0` (must bundle
   pgvecto.rs). Do NOT use a vchord-only tag (e.g. `16-vectorchord1.1.1-pgvector0.8.5`)
   for the migration — it cannot read the pgvecto.rs data. Confirm at
   [GHCR postgres tags](https://github.com/immich-app/immich/pkgs/container/postgres).
2. **[VERIFY] Custom Postgres Deployment vs Immich image expectations.** This
   deployment hand-rolls Postgres (probes, NFS sentinel initContainer, `Recreate`
   strategy) instead of a chart. Confirm the Immich Postgres image starts correctly
   with these probes and does **not** need a custom `command`/`args` that would drop
   its VectorChord `shared_preload_libraries`. Adjust probes if the health command
   path differs.
3. **[VERIFY] Helm chart 0.10.3 vs Immich v3.** Chart version and app version are
   decoupled. Confirm `0.10.3` renders valid manifests for a `v3` image, or bump
   `spec.sources[1].targetRevision` to a chart release that officially supports v3.
4. **[VERIFY] Removed env vars (§3.5).** Cross-check the 3.0 breaking-change changelog
   against the env vars set in `immich.yaml`/`postgres.yaml`.
5. **[VERIFY] Repo API scripts (§3.6).** `scripts/immich-upload` (multipart
   `deviceAssetId`/`deviceId`) and `scripts/immich-export` (`duration` now ms) may
   need edits after the v3 bump. Test both against v3 and fix in `dotfiles`.
6. **Reindex duration / resource pressure.** On the 4-core N100s the VectorChord
   reindex and v3 migrations compete for CPU with ML jobs. Consider pausing heavy job
   queues (faceDetection etc. — see the f3s Immich skill's job-control section) during
   the migration windows to speed them up.
7. **NFS/CARP state during the change.** Take the ZFS snapshot on the **MASTER**, and
   avoid doing the upgrade during/around a CARP failover. A stale NFS bind-mount would
   look like DB corruption. Confirm mounts are healthy first.
8. **zrepl interaction with manual snapshots/rollback.** Manual snapshots use a
   non-`zrepl_` prefix so they survive pruning, but a full `zfs rollback -r` destroys
   newer snapshots and disrupts the f0→f1 replication chain — coordinate with the
   storage/zrepl runbook if it comes to that.
9. **Downgrade is effectively impossible post-VectorChord.** Accept that Stage A is a
   one-way door (no Immich < v1.133.0 afterward). The only real "undo" is
   restore-from-backup. This is the single most important reason §2 is mandatory.
10. **Does Immich 3.0 actually exist / is it stable at execution time?** This runbook
    is written against the published v3.0.0 release notes. Re-check the current stable
    `v3.x.y` and read the latest
    [breaking-change discussions](https://github.com/immich-app/immich/discussions?discussions_q=label%3Achangelog%3Abreaking-change)
    at execution time — later 3.x patches may add notes not covered here.

---

## Sources

- [Immich v3.0.0 release blog](https://immich.app/blog/v3.0.0-release)
- [Immich v3.0.0 GitHub release](https://github.com/immich-app/immich/releases/tag/v3.0.0)
- [Upgrading | Immich docs](https://docs.immich.app/install/upgrading/)
- [Pre-existing / standalone Postgres | Immich docs](https://docs.immich.app/administration/postgres-standalone/)
- [v1.133.0 VectorChord migration — discussion #18429](https://github.com/immich-app/immich/discussions/18429)
- [ghcr.io/immich-app/postgres image tags](https://github.com/immich-app/immich/pkgs/container/postgres)
- [Post-migration failure report — issue #29983](https://github.com/immich-app/immich/issues/29983)
- Repo files: `~/git/conf/f3s/argocd-apps/services/immich.yaml`,
  `~/git/conf/f3s/immich/helm-chart/templates/postgres.yaml`,
  `~/git/conf/f3s/immich/helm-chart/templates/persistent-volume.yaml`,
  `~/git/conf/f3s/immich/{values.yaml,README.md,Justfile,helm-chart/Chart.yaml}`
- f3s skill references: `immich.md`, `storage.md`, `storage/zfs.md`,
  `storage/nfs.md`, `storage/zrepl.md`, `storage/carp.md`
- Repo API tooling: `~/git/dotfiles/scripts/immich-upload`,
  `~/git/dotfiles/scripts/immich-export`
