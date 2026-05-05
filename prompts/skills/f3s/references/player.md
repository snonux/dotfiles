# Player Deployment

Player is deployed on the f3s k3s cluster as a GitOps-managed service.

## Repositories and paths

- App source: `~/git/player`
- f3s config source: `~/git/conf`
- Helm chart: `~/git/conf/f3s/player/helm-chart`
- ArgoCD app: `~/git/conf/f3s/argocd-apps/services/player.yaml`
- External URL: `https://player.f3s.buetow.org`
- LAN URL: `https://player.f3s.lan.buetow.org`

ArgoCD reads the chart from the in-cluster git-server repo:

```sh
http://git-server.cicd.svc.cluster.local/conf.git
path: f3s/player/helm-chart
```

Keep `~/git/conf` pushed to both remotes after chart updates:

```sh
git push master master
git push r0 master
```

## Build and push a new image

Use the app git commit SHA as the immutable image tag.

```sh
cd ~/git/player
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

Update these fields in `~/git/conf/f3s/player/helm-chart`:

- `Chart.yaml`: `appVersion: "<TAG>"`
- `templates/deployment.yaml`: `image: registry.lan.buetow.org:30001/player:<TAG>`

Validate locally:

```sh
cd ~/git/conf
helm template player f3s/player/helm-chart >/tmp/player-helm-render.yaml
kubectl apply --dry-run=client -f /tmp/player-helm-render.yaml
```

Commit and push:

```sh
git add f3s/player/helm-chart
git commit -m "Update player image tag"
git push master master
git push r0 master
```

Refresh ArgoCD and wait for rollout:

```sh
kubectl annotate application player -n cicd argocd.argoproj.io/refresh=normal --overwrite
kubectl rollout status deployment/player -n services --timeout=180s
kubectl get application player -n cicd -o jsonpath='sync={.status.sync.status} health={.status.health.status} revision={.status.sync.revision}{"\n"}'
```

## Storage notes

Player uses two static `hostPath` PVs that point at the NFS mount available on every k3s node:

- `/data/nfs/k3svolumes/player/data` mounted at `/data`
- `/data/nfs/k3svolumes/player/media` mounted at `/media`

The PVs must use:

```yaml
hostPath:
  type: Directory
```

Do not change them to `DirectoryOrCreate`. `Directory` makes pod startup fail if the final path is missing, which helps avoid accidentally creating player data on a node when the intended NFS-backed path is unavailable.

Create the paths before first deploy:

```sh
ssh -p 22 root@192.168.1.120 'mkdir -p /data/nfs/k3svolumes/player/{data,media}'
```

The NFS export may reject `chown` to UID 65534. Existing f3s writable service directories often use mode `777` when ownership cannot be changed:

```sh
ssh -p 22 root@192.168.1.120 'chmod 777 /data/nfs/k3svolumes/player /data/nfs/k3svolumes/player/data /data/nfs/k3svolumes/player/media'
```

## Verification

```sh
kubectl get pods,pvc,svc,ingress -n services | grep player
kubectl logs -n services deploy/player --tail=100
curl -fsS https://player.f3s.buetow.org/healthz
curl -kfsS https://player.f3s.lan.buetow.org/healthz
curl -kfsS https://player.f3s.lan.buetow.org/readyz
```

Verify the runtime UID and NFS write access:

```sh
POD=$(kubectl get pod -n services -l app=player -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n services "$POD" -- id
kubectl exec -n services "$POD" -- sh -c 'touch /data/.write-test /media/.write-test && rm /data/.write-test /media/.write-test'
```
