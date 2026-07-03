# yChat Deployment

yChat is a legacy (2007) C++ HTTP web chat server, revived to build in Docker
with a mandatory embedded-SQLite backend. It is deployed on the f3s k3s
cluster as a GitOps-managed service.

> **Not yet deployed as of this writing.** The live cluster
> (`https://ychat.f3s.lan.buetow.org/`) still runs an **older, in-memory-only,
> no-database image**. Rolling out the current DB-backed build is a deliberate
> follow-up, not automatic: it needs a persistent volume (PVC) for `/app/data`
> — the existing Helm chart was written for the no-DB build and doesn't
> provision one yet.

## Repositories and paths

- App source: `~/git/ychat` (subproject `ychat/`; source on
  https://codeberg.org/snonux/ychat)
- f3s config source: `~/git/conf` (mirrored on the in-cluster git-server;
  https://codeberg.org/snonux/conf)
- Helm chart: `f3s/ychat/helm-chart`
- ArgoCD app: `f3s/argocd-apps/services/ychat.yaml`
- LAN URL: `https://ychat.f3s.lan.buetow.org/`

## Build and push a new image

Use the app git commit SHA as the immutable image tag. Build is a multi-stage
`Dockerfile` (Rocky Linux 9 builder + slim Rocky 9 runtime) that compiles
ychat entirely inside the container.

```sh
cd ~/git/ychat/ychat
podman build -t ychat:dev .

TAG=$(git rev-parse --short HEAD)
podman tag ychat:$TAG r0.lan.buetow.org:30001/ychat:$TAG
podman tag ychat:latest r0.lan.buetow.org:30001/ychat:latest
podman push --tls-verify=false r0.lan.buetow.org:30001/ychat:$TAG
podman push --tls-verify=false r0.lan.buetow.org:30001/ychat:latest
```

The registry is the f3s private registry on NodePort `30001` (plain
HTTP/insecure). In Kubernetes manifests, pods pull the image as:

```text
registry.lan.buetow.org:30001/ychat:<TAG>
```

## Deploy (GitOps)

Config lives in the `conf` repo (mirrored on the in-cluster git-server):

- Helm chart: `f3s/ychat/helm-chart`
- ArgoCD app: `f3s/argocd-apps/services/ychat.yaml`

The Deployment pulls `registry.lan.buetow.org:30001/ychat:<TAG>` (tag matches
`appVersion` in `Chart.yaml`). The default chat port is **2000**.

## Storage notes

- **Logs** (`/app/log`: `access_log`, `system_log`, `rooms/<room>`) go to an
  `emptyDir` — ephemeral by design.
- **SQLite database** (`/app/data/ychat.db`) holds registered accounts and
  needs a real persistent volume (PVC) to survive pod rescheduling. The
  current Helm chart doesn't provision one — this is the main blocker for
  rolling out the DB-backed build.

Only registered accounts persist (in SQLite). Sessions/rooms/online-state are
in-memory, and unregistered `chat.enableguest=true` guest chatters are wiped
on restart — only the accounts table persists.

## Follow-ups before this build goes live

- Provision a PVC for `/app/data` and update the Helm chart.
- Deploy the DB-backed image and ArgoCD-sync it.
