# yChat Deployment

yChat is a legacy (2007) C++ HTTP web chat server, revived to build in Docker
with a mandatory embedded-SQLite backend. It is deployed on the f3s k3s
cluster as a GitOps-managed service.

> **Deployed.** The live LAN URL **https://ychat.f3s.lan.buetow.org/** serves
> image tag `67babb2` (the DB-backed build), with a persistent volume
> (`ychat-data-pvc`, hostPath-backed NFS share) mounted at `/app/data`, so
> registered accounts survive pod restarts. The no-DB build that previously
> ran live has been retired.

This reference is the single home for f3s-specific deployment details. The
public app repo (`ychat` on https://codeberg.org/snonux/ychat) deliberately
keeps deployment/cluster specifics **out of scope** — everything below lives
here instead.

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
  is backed by the `ychat-data-pvc` persistent volume (hostPath-backed NFS
  share, mounted at `/app/data`), so accounts survive pod rescheduling.

Only registered accounts persist (in SQLite). Sessions/rooms/online-state are
in-memory, and unregistered `chat.enableguest=true` guest chatters are wiped
on restart — only the accounts table persists.

## Runtime config notes

- Configuration is `ychat/etc/ychat.conf`, baked into the image at
  `/app/etc/ychat.conf`. Any config key can be overridden at runtime with
  `-o <key> <value>` (the image already does this for
  `chat.session.md5hash=false` and `chat.database.dbname=data/ychat.db`).
- The `/exec` command module is removed from the image entirely
  (defense-in-depth against its shell-injection RCE), and operator status
  via `chat.defaultop` requires a database-authenticated registered account —
  an unregistered guest can never claim it.