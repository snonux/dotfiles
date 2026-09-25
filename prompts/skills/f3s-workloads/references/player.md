# Player Deployment

Player is deployed on the f3s k3s cluster as a GitOps-managed service.

## Repositories and paths

- App source: `~/git/player` (server in `player-server/`, Android app in `player-android/`)
- f3s config source: `~/git/conf`
- Helm chart: `~/git/conf/f3s/player/helm-chart`
- ArgoCD app: `~/git/conf/f3s/argocd-apps/services/player.yaml`
- External URL: `https://player.f3s.buetow.org`
- Extra instance URL: `https://xplayer.f3s.buetow.org`
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

Keep `~/git/conf` pushed to both remotes after chart updates:

```sh
git push master master
git push forgejo master
```

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
git push master master
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

Player uses two static `hostPath` PVs that point at the NFS mount available on every k3s node:

- `/data/nfs/k3svolumes/player/data` mounted at `/data`
- `/data/nfs/k3svolumes/player/media` mounted at `/media`

The `xplayer` instance uses separate static `hostPath` PVs under:

- `/data/nfs/k3svolumes/xplayer/data` mounted at `/data`
- `/data/nfs/k3svolumes/xplayer/media` mounted at `/media`

The PVs must use:

```yaml
hostPath:
  type: Directory
```

Do not change them to `DirectoryOrCreate`. `Directory` makes pod startup fail if the final path is missing, which helps avoid accidentally creating player data on a node when the intended NFS-backed path is unavailable.

Create the paths before first deploy:

```sh
ssh -p 22 root@192.168.1.120 'mkdir -p /data/nfs/k3svolumes/player/{data,media}'
ssh -p 22 root@192.168.1.120 'mkdir -p /data/nfs/k3svolumes/xplayer/{data,media}'
```

The NFS export may reject `chown` to UID 65534. Existing f3s writable service directories often use mode `777` when ownership cannot be changed:

```sh
ssh -p 22 root@192.168.1.120 'chmod 777 /data/nfs/k3svolumes/player /data/nfs/k3svolumes/player/data /data/nfs/k3svolumes/player/media'
ssh -p 22 root@192.168.1.120 'chmod 777 /data/nfs/k3svolumes/xplayer /data/nfs/k3svolumes/xplayer/data /data/nfs/k3svolumes/xplayer/media'
```

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
