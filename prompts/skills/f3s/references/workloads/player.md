# Player Deployment

Player is deployed on the f3s k3s cluster as a GitOps-managed service.

## Repositories and paths

- App source: `~/git/player` (server in `player-server/`, Android app in `player-android/`)
- f3s config source: `~/git/conf`
- Helm chart: `~/git/conf/f3s/player/helm-chart`
- ArgoCD app: `~/git/conf/f3s/argocd-apps/services/player.yaml`
- External URL: `https://player.f3s.buetow.org`
- Extra instance URL: `https://xplayer.f3s.buetow.org`
- Isolated trash-test URL: `https://player-test.f3s.buetow.org` (namespace `player-trash-test`; manifests in `~/git/player/player-server/k8s/test-trash/`)
- LAN URL: `https://player.f3s.lan.buetow.org`

ArgoCD reads the chart from the in-cluster Forgejo repo:

```sh
http://forgejo.services.svc.cluster.local/snonux/conf.git
path: f3s/player/helm-chart
```

The secondary `xplayer` instance is managed by a separate ArgoCD app:

```sh
http://forgejo.services.svc.cluster.local/snonux/conf.git
path: f3s/xplayer/helm-chart
```

Keep `~/git/conf` pushed to both remotes after chart updates. The repo moved
off Codeberg in October 2026, so the old `master` remote (Codeberg) rejects
pushes; GitHub is the canonical home:

```sh
git push github master
git push forgejo master
```

## Test ingress naming

Use `X-test.f3s.buetow.org` for test instances, with `www.` and `standby.`
aliases where needed. Gogios excludes only the `-test.f3s.buetow.org` suffix
from all site checks. DNS, ACME certificates and routing still come from the
frontend topology in `conf/gonf/frontends/data.go`; the ingress remains in
the application repo. Use `player-test`, replacing the former `test-player`
name; use `test` rather than `testing` in test ingress domains. The isolated
trash browser suite must target this test instance, never production. After
a rename, verify HTTPS pinned to each frontend gateway: DNS failover can
select either gateway, so both need the issued certificate rather than a
placeholder.

## Build and push a new image

Use the app git commit SHA as the immutable image tag.

`~/git/player` is a monorepo; the Go server, its `Dockerfile` and
`.dockerignore` live in `player-server/`. Build from that directory. The
`.dockerignore` keeps the large local `testmedia/` library (~200 GB) out of
the build context; without it the build fills the disk.

```sh
cd ~/git/player/player-server
go test ./...

TAG=$(git rev-parse --short HEAD)
podman build -t player:$TAG -t player:latest .
podman tag player:$TAG r0.lan.buetow.org:30001/player:$TAG
podman tag player:latest r0.lan.buetow.org:30001/player:latest
podman push --tls-verify=false r0.lan.buetow.org:30001/player:$TAG
podman push --tls-verify=false r0.lan.buetow.org:30001/player:latest
```

The registry is the f3s private registry on NodePort `30001` and is plain HTTP/insecure. In Kubernetes manifests, pods pull the image as:

```text
registry.lan.buetow.org:30001/player:<TAG>
```

The app must not run as root. The Dockerfile runtime stage uses `USER 65534:65534`, and the chart should keep:

```yaml
runAsNonRoot: true
runAsUser: 65534
runAsGroup: 65534
fsGroup: 65534
```

## Update Helm and ArgoCD

Update the same image tag in both Helm charts:

`~/git/conf/f3s/player/helm-chart`:

- `Chart.yaml`: `appVersion: "<TAG>"`
- `templates/deployment.yaml`: `image: registry.lan.buetow.org:30001/player:<TAG>`

`~/git/conf/f3s/xplayer/helm-chart`:

- `Chart.yaml`: `appVersion: "<TAG>"`
- `templates/deployment.yaml`: `image: registry.lan.buetow.org:30001/player:<TAG>`

Validate locally:

```sh
cd ~/git/conf
helm template player f3s/player/helm-chart >/tmp/player-helm-render.yaml
helm template xplayer f3s/xplayer/helm-chart >/tmp/xplayer-helm-render.yaml
kubectl apply --dry-run=client -f /tmp/player-helm-render.yaml
kubectl apply --dry-run=client -f /tmp/xplayer-helm-render.yaml
```

Commit and push. `~/git/conf` often has unrelated uncommitted work in other
charts, so stage the player files by explicit path, never `git add -A`:

```sh
git add f3s/player/helm-chart/Chart.yaml f3s/player/helm-chart/templates/deployment.yaml \
  f3s/xplayer/helm-chart/Chart.yaml f3s/xplayer/helm-chart/templates/deployment.yaml
git commit -m "Update player image tags"
git push github master
git push forgejo master   # ArgoCD reads the in-cluster Forgejo repo
```

Refresh ArgoCD and wait for rollout:

```sh
kubectl annotate application player -n cicd argocd.argoproj.io/refresh=normal --overwrite
kubectl annotate application xplayer -n cicd argocd.argoproj.io/refresh=normal --overwrite
kubectl rollout status deployment/player -n services --timeout=180s
kubectl rollout status deployment/xplayer -n services --timeout=180s
kubectl get application player -n cicd -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}'
kubectl get application xplayer -n cicd -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}'
```

## Storage notes

Player uses static `hostPath` PVs that point at the NFS mount available on every k3s node. Its own data:

- `/data/nfs/k3svolumes/player/data` mounted at `/data`
- `/data/nfs/k3svolumes/player/media` mounted at `/media`

The `xplayer` instance uses separate static `hostPath` PVs under:

- `/data/nfs/k3svolumes/xplayer/data` mounted at `/data`
- `/data/nfs/k3svolumes/xplayer/media` mounted at `/media`

Each instance also has a `<app>/thumbnails` volume mounted at `/thumbnails`
(`THUMBNAIL_CACHE_DIR=/thumbnails`, since image `879f2d7`): all generated
thumbnails live there, not in `.thumbnails` directories next to the media.

Since 2026-10-13 the sets are existing libraries of other services, mounted
**read-only** in place (no copies) with `subPath` from extra PVs that point
at the other chart's PV root, where the `.nfs-sentinel` lives:

| Instance | Set (= directory under `/media`) | NFS path under `/data/nfs/k3svolumes` |
|---|---|---|
| player | Music | `navidrome/music` |
| player | Audiobooks | `audiobookshelf/audiobooks/default` |
| player | Music Videos | `jellyfin/libraries/musicvideos` |
| player | Yoga | `jellyfin/libraries/yoga` |
| player | Irregular Ninja | `syncthing/data/paul/Pixel7Pro/DCIM/Irregular Ninja` |
| xplayer | AI, Pictures, Videos | `jellyfin/libraries/xman/{ai,pictures,videos}` |

The empty mount-point directories exist in `<app>/media` on NFS. A new set
only appears after an admin **Rescan**. Player runs as UID 65534, so files
in those libraries that are not world-readable (mode `0600`) are skipped
with "permission denied". Uploads, deletes and "regenerate cover" do not
work on these sets. Logins for both sites are in foostore
(`pass/player.f3s.buetow.org-paul.txt`, `…-xman.txt`,
`pass/xplayer.f3s.buetow.org-xman.txt`).

Operating the library sets:

- The `nfs-check-*` init containers also require each mounted subdirectory
  to exist. If a library folder is renamed or removed (in Jellyfin, on the
  phone, …) the pod refuses to start (`Init:CrashLoopBackOff`) rather than
  let kubelet create an empty directory there. Fix the path in the chart.
- `hostPath` and the claim binding are immutable: to point a set elsewhere,
  scale the deployment down and delete that PV and PVC by hand before
  syncing, or ArgoCD ends in `SyncFailed`.
- Removing a set: drop its mount from the chart, remove the empty
  mount-point directory from `<app>/media`, then delete the set row with
  `sqlite3` (`PRAGMA foreign_keys=ON; DELETE FROM sets WHERE name='…';`,
  after backing up `media.db`). There is no API for it; a leftover mount
  point shows as an empty set and a rescan trashes its items.
- Every new `<app>/…` directory that is a PV root needs `chmod 777` and a
  `.nfs-sentinel` (see `docs/nfs-sentinel-initcontainer.md` in conf).

The PVs must use:

```yaml
hostPath:
  type: Directory
```

Do not change them to `DirectoryOrCreate`. `Directory` makes pod startup fail if the final path is missing, which helps avoid accidentally creating player data on a node when the intended NFS-backed path is unavailable.

Create the paths before first deploy:

```sh
ssh -p 22 root@192.168.1.120 'mkdir -p /data/nfs/k3svolumes/player/{data,media,thumbnails}'
ssh -p 22 root@192.168.1.120 'mkdir -p /data/nfs/k3svolumes/xplayer/{data,media,thumbnails}'
```

The NFS export may reject `chown` to UID 65534. Existing f3s writable service directories often use mode `777` when ownership cannot be changed:

```sh
ssh -p 22 root@192.168.1.120 'chmod 777 /data/nfs/k3svolumes/player /data/nfs/k3svolumes/player/data /data/nfs/k3svolumes/player/media'
ssh -p 22 root@192.168.1.120 'chmod 777 /data/nfs/k3svolumes/xplayer /data/nfs/k3svolumes/xplayer/data /data/nfs/k3svolumes/xplayer/media'
```

## Transcoding (since v0.3.0)

The server converts formats browsers and Android cannot decode (AVI, WMV,
FLV, WMA, …) with ffmpeg and caches the result next to the database, in
`/data/media.db.transcode-cache` (NFS-backed, default budget 4096 MB via
`TRANSCODE_CACHE_MAX_MB`; one job at a time via `TRANSCODE_MAX_JOBS`).

- Both charts set the memory limit to `1Gi`: one ffmpeg job needs about
  400 MB next to the server. Do not lower it back to 512Mi.
- With the 1-CPU limit a long 1080p re-encode can exceed the 2 h job timeout;
  short and SD files are fine.
- After upgrading from v0.2.2 or older, trigger one admin **Rescan** per
  instance: it regenerates every thumbnail under the new naming
  (`.thumbnails/<file name>.jpg`, on f3s below `/thumbnails`, see
  "Storage notes").
- The schema setup at startup rewrites old timestamps to UTC and removes
  orphaned rows; back up `media.db` before an upgrade
  (`cp media.db media.db.pre-<version>-<date>` on the NFS volume).

## End-to-end tests against the deployed instances

Both instances used to hold three generated sets, `test-videos`,
`test-audio` and `test-images` (one `sample-<ext>.<ext>` per supported
extension, made by `player-server/testdata/gen-all-formats.sh`). They were
removed on 2026-10-13; recreate them in `<app>/media` (and rescan) before
running the two suites that use them:

- Web: `player-server/test/e2e-web`, `npx playwright test -c playwright.live.config.ts`
  with `PLAYER_URL` and the `E2E_*` variables (about 5 minutes per instance).
- Android: `player-android/test/e2e-live/android_e2e.py <base-url>` with the
  release APK installed in the `Player_FDroid_Test_API34` emulator (about
  20 minutes per instance); see its README.

Both need an admin and a regular test account, read from
`~/.config/player-e2e.env`. There is no password reset, so temporary accounts
are created by hand and removed afterwards:

1. Back up `media.db`, then insert a temporary admin with `sqlite3` on an
   r-node that has it (r2), feeding the SQL through stdin so the `$` in the
   bcrypt hash is not expanded by the remote shell
   (`htpasswd -bnBC 12 x <password>` gives a hash the server accepts).
2. Create the regular test user through `POST /api/v1/admin/users`.
3. After the runs delete the regular user through the admin API and the
   temporary admin with `sqlite3` (`PRAGMA foreign_keys=ON;` first, so the
   user's sessions go with it), and remove the env file.

## Verification

```sh
kubectl get pods,pvc,svc,ingress -n services | grep player
kubectl logs -n services deploy/player --tail=100
kubectl logs -n services deploy/xplayer --tail=100
curl -fsS https://player.f3s.buetow.org/healthz
curl -fsS https://xplayer.f3s.buetow.org/healthz
curl -kfsS https://player.f3s.lan.buetow.org/healthz
curl -kfsS https://player.f3s.lan.buetow.org/readyz
```

`curl https://<host>/` returns `401 unauthorized` for non-browser clients;
browsers (`Accept: text/html`) get a `307` to `/login.html`. That is expected.

There is no admin-password env override and no password reset: accounts live
in `/data/media.db` (player: `paul` admin, `xman` user; xplayer: `xman`
admin). To test the logged-in UI without real credentials, run the same image
locally with a fresh DB and `player-server/testdata/media`, then run the
Playwright suite against it:

```sh
podman run -d --name player-imgtest -p 18090:8080 --userns=keep-id:uid=65534,gid=65534 \
  -v /tmp/imgtest/data:/data:Z -v /tmp/imgtest/media:/media:Z \
  -e DB_PATH=/data/media.db -e MEDIA_ROOT=/media -e SECURE_COOKIES=false \
  r0.lan.buetow.org:30001/player:$TAG
cd ~/git/player/player-server/test/e2e-web && PLAYER_URL=http://127.0.0.1:18090 npx playwright test
podman rm -f player-imgtest
```

Verify the runtime UID and NFS write access:

```sh
POD=$(kubectl get pod -n services -l app=player -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n services "$POD" -- id
kubectl exec -n services "$POD" -- sh -c 'touch /data/.write-test /media/.write-test && rm /data/.write-test /media/.write-test'
XPOD=$(kubectl get pod -n services -l app=xplayer -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n services "$XPOD" -- id
kubectl exec -n services "$XPOD" -- sh -c 'touch /data/.write-test /media/.write-test && rm /data/.write-test /media/.write-test'
```
