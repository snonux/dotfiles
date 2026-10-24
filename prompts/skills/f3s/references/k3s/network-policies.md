# Namespace NetworkPolicies

Task 7n3 was approved and deployed on 2026-10-24. All eleven namespace
stages are active: 55 task policies plus the two separately owned Prometheus
policies. Eleven healthy manual Applications pin policy commit `a1112b9`.
Inspect live state before maintenance; published files alone are not proof of it.

## Source and ownership

In `~/git/conf`:

- `f3s/network-policies/namespaces/<namespace>/policies.yaml`: receiving rules
  and default deny, managed one namespace at a time.
- `f3s/argocd-apps/network-policies/*.yaml.disabled`: manual Application templates.
  Pin `targetRevision` to a published reviewed commit before creating the
  selected Application. They have no automated sync or finalizer.
- `f3s/network-policies/README.md`: detailed stage gates, evidence and recovery.
- `f3s/prometheus/manifests/prometheus-networkpolicy.yaml`: separately owned
  Prometheus API/proxy policies; namespace rollback must preserve these.

The approved set now has 55 policies across `test`, `default`, `kube-public`,
`kube-node-lease`, `player-trash-test`, `infra`, `services`, `monitoring`,
`cert-manager`, `cicd` and `kube-system`. The extra phone proxy rule was added
at the owner's request after the initial 54-policy preparation.

## Traffic contract

These policies restrict **incoming pod traffic**. They leave egress and
connections initiated by applications unrestricted. A newly added receiving
workload is closed until its required callers and endpoint ports are added.

| Receiver | Required callers |
|---|---|
| Web applications | Traefik pods in kube-system, selected by namespace and labels |
| Postgres, Immich Valkey and ML | Their owning app, never unrelated pods or roaming devices |
| Metrics | The exact Prometheus selector and endpoint port |
| CoreDNS | Pods in every namespace on TCP/UDP53; metrics remain Prometheus-only |
| Admission webhooks/metrics-server | The existing node/API-server paths |
| Argo Redis/repo-server | The selected Argo components, not the entire namespace |

Ports are receiver endpoint ports, which may differ from Service ports.
Each newly selecting allow policy contains its receiver's complete required
flow set; narrow allows already isolate a selected receiver before a namespace
default deny is installed. Policies are additive.

## Laptop and phone over WireGuard

Both gateway peer configurations contain laptop `192.168.2.200` and phone
`192.168.2.201`. Preserve their explicit /32 web and existing client-port
allowances. Reachability does not confer forwarded-header trust: Traefik still
trusts only frontend WG sources `.110` and `.111`.

The read-only Prometheus proxy admits the laptop through its existing policy;
a separate `prometheus-read-proxy-phone` policy admits phone `.201` on proxy
port8080 (NodePort30090). Both devices remain denied raw Prometheus9090 and
application database ports. Do not replace these exact sources with a broad
private-network allowlist.

The laptop currently has no active earth/wg0 `.200` interface; its wg1 `.3.2`
connection is another network. The laptop profile is inactive and the phone was
not available for device-side tests; neither device's packets are claimed
verified. When using either device, verify routing and
real web/proxy access with that device; an allowed policy alone does not prove
WireGuard handshakes, return routes or DNS. Host SSH/API/VPN services are outside
these pod-ingress policies. Preserve the mesh configuration; do not activate or
replace an unrelated VPN as a policy-test shortcut.

## Argo chart ownership

The cicd replacement server, Redis and repo policies use distinct `-scoped`
names. Reusing Helm's existing names would let Helm delete the replacements
when its four broad policies are disabled.

The approved transition retained chart 10.10.5 (release 20 to 21), removed only
the four old chart policies and preserved all five replacement UIDs. For a new
transition, install scoped replacements first, then use the same pinned chart and
existing values with `f3s/network-policies/cicd-chart-values.yaml`. Both standard
Justfile commands include the overlay as of commit `d6687e8`;
`cicd-activation.patch` remains for older checkouts.
Inspect the proposed change for unrelated runtime changes before upgrading.
A later plain Helm upgrade must not recreate the broad allows.

## Inspection and rollback

```sh
kubectl get networkpolicy -A
kubectl -n cicd get applications | rg network-policies
```

Manual sync names exactly one namespace Application. Never recursively activate
all templates or apply all namespaces as a batch. Gate each stage on actual
per-node packets, app/database reads, metrics and normal monitoring; API objects
or the offline model alone are insufficient.

Rollback removes only that stage's complete policy set and restores any chart
transition made in that stage. Removing only default deny leaves receivers
isolated by their allow policies. Deleting a no-finalizer Application does not
remove its policies. Preserve the separately managed Prometheus boundary.

Node/hostNetwork traffic, authenticated exec/port-forward and labels that an
administrator can impersonate are not isolated by this mechanism. Cluster
NodePort SNAT can admit an ordinary pod under a trusted node/CNI identity for
registry, Bridge, Forgejo SSH or Anki; task co3 owns that remaining bypass.
Database Service/Pod denial is separate and still mandatory.

## Verified scope and remaining checks

Every namespace passed 18 actual positive-before and 18 denied-after TCP cases
using temporary ordinary clients/receivers on all three nodes. Services had 48
unrelated-client DB/dependency denials, eight real owning-app positive connections
and two wrong-app denials. Monitoring had 66 receiver denials. Existing 43
healthy targets, 42 rule groups and 55 running workload pod identities/readiness/
restart counts stayed stable. Native DNS UDP/TCP, admission dry runs, Argo
component/GitOps reads and public/LAN routes passed. No workload restart or
storage/host/VPN change was used.

Bridge's current laptop path is a Kubernetes port-forward, not direct access
from frontend WG sources. IMAP and SMTP STARTTLS/NOOP passed against the pinned
certificate; no mail was sent. Traefik still has one replica, so direct Local
NodePort31637 checks use its ready endpoint node. The three read proxies retain
their per-node availability. Do not assume every node runs Traefik.

The known co3 bypass was reproduced from an ordinary r0 pod through r1
NodePorts30001/30222/30143/30025/30800. Direct Service/Pod denials do not remove
that source-translation exception. Actual laptop/phone tunnel tests remain for
when those devices are used.
