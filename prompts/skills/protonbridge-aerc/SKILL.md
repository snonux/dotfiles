---
name: protonbridge-aerc
description: "Manages the local aerc connection to Proton Mail Bridge running in the f3s k3s cluster through a persistent kubectl port-forward, pinned Bridge certificate, and systemd user service. Use when setting up, starting, validating, or troubleshooting aerc, Proton Bridge IMAP/SMTP, certificate errors, credentials, or the protonbridge-k3s-tunnel service. Triggers on: protonbridge aerc, aerc mail, Proton Bridge tunnel, aerc IMAP, aerc SMTP."
---

# Proton Bridge for aerc

Maintain the secure path from aerc on `earth` to Proton Mail Bridge in the f3s
k3s cluster. Do not expose the Bridge-generated password in output, prompts,
logs, Git, or task annotations.

## Architecture

```text
aerc
  ├─ IMAP STARTTLS  127.0.0.1:1143
  └─ SMTP STARTTLS  127.0.0.1:1025
          │
          ▼
protonbridge-k3s-tunnel.service
  └─ kubectl port-forward service/protonbridge -n services
          │
          ▼
Proton Bridge pod in f3s k3s
```

The port-forward is preferable to a fixed NodePort address because Kubernetes
selects the healthy pod and the setup survives r0/r1/r2 placement changes.

## Canonical files

| Purpose | Path |
|---|---|
| aerc account | `~/.config/aerc/accounts.conf` |
| Bridge password | `~/.config/aerc/protonbridge-password` (mode `0600`) |
| Pinned Bridge certificate | `~/.config/aerc/protonbridge-ca-bundle.pem` |
| aerc wrapper setting `SSL_CERT_FILE` | `~/bin/aerc` |
| Persistent tunnel | `~/.config/systemd/user/protonbridge-k3s-tunnel.service` |
| Disabled old local Bridge autostart | `~/.config/autostart/Proton Mail Bridge.desktop` |
| k3s Deployment | `/home/paul/git/conf/f3s/protonbridge/helm-chart/templates/deployment.yaml` |
| k3s Service | `/home/paul/git/conf/f3s/protonbridge/helm-chart/templates/service.yaml` |
| Argo CD Application | `/home/paul/git/conf/f3s/argocd-apps/services/protonbridge.yaml` |

Load the [`f3s-k3s`](../f3s-k3s/SKILL.md) skill for cluster access, Argo CD,
node, or control-plane problems. This skill owns only the Proton Bridge/aerc
path.

## f3s Argo CD deployment

The cluster-side Proton Bridge is a GitOps workload in the `conf` repository,
not an independently managed pod:

- Argo CD Application: `protonbridge` in namespace `cicd`
- Application manifest:
  `/home/paul/git/conf/f3s/argocd-apps/services/protonbridge.yaml`
- Argo source repository:
  `http://git-server.cicd.svc.cluster.local/conf.git`
- Source revision and path: `master`, `f3s/protonbridge/helm-chart`
- Destination: the in-cluster API, namespace `services`
- Desired policy: automated sync with `prune: true` and `selfHeal: true`

The Helm chart owns:

- `templates/deployment.yaml` — headless Bridge CLI, persistent account/update
  state, probes, and loopback-to-pod forwarding
- `templates/service.yaml` — IMAP/SMTP Service ports plus LAN NodePorts
- `templates/persistent-volumes.yaml` — retained Bridge state on the f3s volume

Treat these files as the source of truth. Make durable cluster-side fixes in
the chart, validate them, commit them to the `conf` repository, and push through
the established repository workflow so Argo CD deploys them. A direct
`kubectl apply` is acceptable for a short diagnostic only; reproduce any valid
fix in Git and remove live drift afterward.

Validate a chart change before pushing:

```bash
cd /home/paul/git/conf
helm lint f3s/protonbridge/helm-chart
helm template protonbridge f3s/protonbridge/helm-chart \
  | kubectl apply --dry-run=server -f -
```

Inspect reconciliation and the deployed revision:

```bash
kubectl get application -n cicd protonbridge \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{" "}{.status.sync.revision}{"\n"}'
kubectl get deployment,pod -n services -l app=protonbridge
kubectl get service,endpoints -n services protonbridge
```

If automated sync was temporarily disabled during diagnosis, restore the
declared Application and verify the policy rather than leaving it disabled:

```bash
kubectl apply -f /home/paul/git/conf/f3s/argocd-apps/services/protonbridge.yaml
kubectl get application -n cicd protonbridge \
  -o jsonpath='{.spec.syncPolicy.automated}{"\n"}{.status.sync.status}{" "}{.status.health.status}{"\n"}'
```

Expected output includes `{"prune":true,"selfHeal":true}` and
`Synced Healthy`. Never delete the retained PV/PVC or Bridge vault as a generic
troubleshooting step; they contain the persisted account session, generated
credentials, certificate, and self-update state.

## Bootstrap order

When recreating the setup on `earth`:

1. Confirm `kubectl` can reach the f3s cluster and Proton Bridge is healthy.
2. Create and enable the systemd port-forward described below.
3. Attach to Bridge, run `info`, and store its generated password without
   printing or committing it.
4. Capture and pin the current Bridge certificate through the localhost tunnel.
5. Create the aerc account with credential commands instead of inline secrets.
6. Install the `~/bin/aerc` wrapper and confirm it is first on `PATH`.
7. Disable the obsolete laptop-local Bridge autostart to prevent port conflicts.
8. Run TLS, IMAP login/folder, SMTP authentication, and aerc startup checks.

Do not continue to a later layer when an earlier one is unhealthy.

## Expected aerc account

The account uses STARTTLS through localhost and obtains the password through a
credential command:

```ini
[paul]
source        = imap://mail%40paul.buetow.org@127.0.0.1:1143
source-cred-cmd = cat ~/.config/aerc/protonbridge-password
outgoing      = smtp://mail%40paul.buetow.org@127.0.0.1:1025
outgoing-cred-cmd = cat ~/.config/aerc/protonbridge-password
default       = INBOX
from          = Paul Buetow <mail@paul.buetow.org>
copy-to       = Sent
cache-headers = true
```

Never put the password back into either URI. It is the Bridge-generated
password shown by the Bridge `info` command, not the Proton account password.

The `~/bin/aerc` wrapper must precede `/usr/bin` on `PATH` and contain:

```sh
#!/bin/sh
export SSL_CERT_FILE="$HOME/.config/aerc/protonbridge-ca-bundle.pem"
exec /usr/bin/aerc "$@"
```

## Start and inspect

Start or restart the persistent tunnel:

```bash
systemctl --user enable --now protonbridge-k3s-tunnel.service
systemctl --user restart protonbridge-k3s-tunnel.service
```

Check it without printing secrets:

```bash
systemctl --user status protonbridge-k3s-tunnel.service --no-pager
journalctl --user -u protonbridge-k3s-tunnel.service --since '-15 min' --no-pager
ss -ltn | rg '127\.0\.0\.1:(1025|1143)\b'
type -a aerc
```

Expected state:

- service is `enabled` and `active`
- `kubectl port-forward` listens on localhost ports 1143 and 1025
- `~/bin/aerc` resolves before `/usr/bin/aerc`
- no laptop-local `/usr/lib/protonmail/bridge/` process is running

Launch normally with `aerc`.

## End-to-end health check

Check the cluster first:

```bash
kubectl get pod -n services -l app=protonbridge
kubectl get service,endpoints -n services protonbridge
kubectl get application -n cicd protonbridge \
  -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{"\n"}'
```

The pod should be `1/1 Running`, endpoints should include IMAP and SMTP, and
Argo CD should report `Synced Healthy`.

Validate TLS without authenticating:

```bash
/usr/bin/openssl s_client -starttls imap \
  -connect 127.0.0.1:1143 \
  -verify_return_error \
  -CAfile ~/.config/aerc/protonbridge-ca-bundle.pem \
  -brief </dev/null

/usr/bin/openssl s_client -starttls smtp \
  -connect 127.0.0.1:1025 \
  -verify_return_error \
  -CAfile ~/.config/aerc/protonbridge-ca-bundle.pem \
  -brief </dev/null
```

Both must report `Verification: OK`. Do not work around failures with
`imap+insecure` or `smtp+insecure`: in aerc 0.21 those schemes disable STARTTLS
and expose credentials as plaintext.

For an authenticated check, read the password from the credential file inside
the test process; never echo it. Use Python `imaplib.IMAP4` followed by
`starttls()`, and `smtplib.SMTP` followed by `starttls()`, with an SSL context
created from `protonbridge-ca-bundle.pem`. Confirm IMAP login/folder listing and
SMTP login, then log out without sending mail.

## Recreate the tunnel

The systemd user unit should contain:

```ini
[Unit]
Description=Forward local aerc ports to the Proton Bridge k3s service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/kubectl port-forward --address 127.0.0.1 --namespace services service/protonbridge 1143:1143 1025:1025
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

After creating or changing it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now protonbridge-k3s-tunnel.service
```

## Refresh credentials

Refresh only after an authenticated check proves the saved password is stale.
The Bridge pod runs an attachable CLI:

```bash
pod=$(kubectl get pod -n services -l app=protonbridge \
  -o jsonpath='{.items[0].metadata.name}')
kubectl attach -it -n services "$pod"
```

Press Enter if needed, run `info`, and use its Bridge-generated password. Write
it directly to `~/.config/aerc/protonbridge-password`, apply mode `0600`, and do
not show it in command output. Typing `quit` exits Bridge; Kubernetes restarts
the pod and reconnects with its persisted session.

If the account itself is absent, run `login` in the attached CLI. The user must
enter the Proton credentials and 2FA interactively. Never request or retain the
Proton account password.

## Refresh the pinned certificate

Bridge uses a self-signed certificate whose SAN is only `127.0.0.1`. This is
why aerc connects through the localhost port-forward instead of directly to a
NodePort. If Bridge rotates the certificate, replace the pinned leaf after
verifying that the cluster pod and account are expected:

```bash
umask 077
tmp=$(mktemp)
timeout 10 /usr/bin/openssl s_client \
  -starttls imap -connect 127.0.0.1:1143 -showcerts \
  </dev/null 2>/dev/null \
  | /usr/bin/openssl x509 -outform PEM >"$tmp"
test -s "$tmp"
install -m 0644 "$tmp" ~/.config/aerc/protonbridge-ca-bundle.pem
rm -f "$tmp"
```

Then rerun both TLS checks. Keep this file limited to the current Bridge
certificate; combining it with Fedora's CA bundle can select an older
self-signed Bridge certificate with the same `127.0.0.1` subject.

## Troubleshooting order

1. **aerc binary** — `type -a aerc`; ensure `~/bin/aerc` is first.
2. **Local listeners** — check ports 1143/1025 with `ss`.
3. **Tunnel service** — inspect status and journal; restart it once after
   reading the error.
4. **kubectl access** — run `kubectl get service -n services protonbridge`.
   Fix kube context/network access before changing aerc.
5. **Cluster health** — inspect pod readiness, restarts, logs, endpoints, and
   Argo CD status.
6. **TLS** — run the pinned-certificate checks. Refresh the pin only if the
   live certificate changed intentionally.
7. **Authentication** — run a non-printing IMAP/SMTP login check. Refresh the
   Bridge-generated password only if login fails after transport and TLS pass.

Common failures:

- `connection refused`: tunnel inactive, port collision, or pod unavailable.
- `error upgrading connection` / port-forward exits: stale kube context,
  unreachable API server, or no ready Proton Bridge pod.
- `certificate signed by unknown authority`: wrapper bypassed or pin missing.
- certificate name mismatch: aerc is connecting directly to an r-node address
  instead of `127.0.0.1`.
- `no such user` / SMTP authentication failure: stale Bridge-generated
  password or wrong full email address.
- local port already in use: stop old laptop-local Bridge processes and keep
  `~/.config/autostart/Proton Mail Bridge.desktop` disabled (`Hidden=true`).
- pod `0/1` with `No active accounts`: attach and perform interactive `login`.
- pod restart after `kubectl attach`: EOF stopped the CLI; wait for Kubernetes
  to restart it and confirm readiness before retrying.

Do not patch around cluster failures by running a second local Bridge. Repair
the owning layer, validate the full path, and preserve the single persisted
Bridge session in k3s.
