# Accessing f3s hosts from outside the LAN (roaming)

When `earth` (or any roaming client) is not on the f3s LAN, the hosts are
unreachable directly. The f-hosts (`f0`–`f3`) and VMs have LAN IPs
(`192.168.1.x`) and WireGuard IPs (`192.168.2.x`), but a roaming laptop's
`wg0` only peers to the OpenBSD gateways — not directly to the homelab mesh.

## Working method: jump through an OpenBSD gateway

**fishfinger** and **blowfish** are reachable from the public internet *and*
sit on the WireGuard mesh, so they can reach all homelab hosts over `wg0`.
Use either as a ProxyJump host.

### Reaching f-hosts (FreeBSD)

The f-hosts allow SSH as **`paul`** (not `root`). Use `doas` on the host for
privileged commands.

Interactive:

```sh
ssh -A rex@fishfinger.buetow.org   # -A forwards your agent for the next hop
ssh paul@f0.wg0                    # from fishfinger, over the WireGuard mesh
doas some-privileged-command       # passwordless doas is configured
```

One-shot from the laptop (handy for scripts/automation):

```sh
ssh -A -J rex@fishfinger.buetow.org paul@f0.wg0 "sh -c 'hostname; doas freebsd-version'"
```

Use `f0.wg0` / `f1.wg0` / `f2.wg0` / `f3.wg0` — the WireGuard hostnames as
seen from the gateway. `f3.wg0` resolves to `192.168.2.133`:

```sh
ssh -A -J rex@fishfinger.buetow.org paul@192.168.2.133   # f3 direct via WireGuard
```

(Previously the f3↔GW WireGuard tunnel was broken due to key mismatches; fixed
in gq0 — pubkeys and PSKs corrected on f3 and on fishfinger/blowfish.)

### Reaching r-VMs (Rocky Linux) and `rocky`

The k3s Rocky VMs (`r0`–`r2`) and the standalone `rocky` VM allow SSH as
**`root`** directly. See [k3s-setup/remote-access.md](k3s-setup/remote-access.md)
for the cluster-access workflow.

```sh
ssh -A -J rex@fishfinger.buetow.org root@r0.wg0 "kubectl get nodes"
ssh -A -J rex@fishfinger.buetow.org root@rocky.wg0 "hostname"
```

### Reaching Pis

```sh
ssh -A -J rex@fishfinger.buetow.org paul@pi0.wg0
```

## Notes

- `ssh -A` (agent forwarding) is required so the `rex@fishfinger` → `paul@fN.wg0`
  hop can authenticate. Make sure the right key is loaded (`ssh-add -l`).
- `blowfish.buetow.org` works as a drop-in replacement if fishfinger is unavailable.
- On a fresh laptop, accept host keys on first connect:
  `-o StrictHostKeyChecking=accept-new` on both hops.
- The f-hosts use `tcsh` as paul's shell — wrap multi-statement commands in
  `sh -c '...'` to avoid tcsh-specific syntax errors.
- The `rex` user on the gateways is the SSH user for the jump; it has no
  privileged access on the f-hosts.
