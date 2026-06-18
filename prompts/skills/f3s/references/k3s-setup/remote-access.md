# Accessing the k3s cluster from outside the LAN (roaming)

The kubeconfig on the laptop points at the **LAN** API endpoint
(`https://r0.lan.buetow.org:6443` → `192.168.1.120`). When **earth** (or any
client) is **not on the f3s LAN**, that address is unreachable and `kubectl`
just times out:

```
Unable to connect to the server: dial tcp 192.168.1.120:6443: i/o timeout
```

The WireGuard mesh IPs (`192.168.2.120` etc.) are also not directly reachable
from a roaming laptop, because the laptop's `wg1` interface does not peer
straight to the r-VMs.

## Working method: jump through an OpenBSD frontend

The OpenBSD internet gateways **fishfinger** and **blowfish** are reachable
from the public internet *and* sit on the WireGuard mesh, so they can reach the
r-VMs over `wg0`. Use one as a jump host, then run `kubectl` as `root` on the
r-VM itself.

Interactive:

```sh
ssh -A rex@fishfinger.buetow.org      # -A forwards your agent for the next hop
ssh root@r0.wg0                       # from fishfinger, over the WireGuard mesh
kubectl get nodes                     # root on r0 has /etc/rancher/k3s/k3s.yaml
```

One-shot (non-interactive) from the laptop — handy for scripts/automation:

```sh
ssh -A rex@fishfinger.buetow.org "ssh root@r0.wg0 'kubectl get nodes'"
```

Notes:

- `ssh -A` (agent forwarding) is required so the `rex@fishfinger` → `root@r0.wg0`
  hop can authenticate. Make sure the right key is loaded (`ssh-add -l`).
- Use **`r0.wg0`** (or `r1.wg0` / `r2.wg0` if r0 is down) — that is the r-VM's
  WireGuard hostname as seen *from the frontend*, not `r0.lan…`.
- `blowfish.buetow.org` works the same way as `fishfinger.buetow.org` if one
  frontend is unavailable.
- On a fresh laptop, accept host keys with
  `-o StrictHostKeyChecking=accept-new` on both hops.
- An OpenSSH **post-quantum key exchange warning** from the `root@r0.wg0` hop is
  harmless and can be ignored.

## Example: issue a goprecords client key while roaming

```sh
ssh -A rex@fishfinger.buetow.org \
  "ssh root@r0.wg0 'kubectl exec -n services deployment/goprecords -- \
     goprecords --create-client-key mega-m3-pro -stats-dir=/data/stats'"
```

## Alternative: serve the API over an SSH tunnel

If you need a real local `kubectl` (not just one-off commands), forward the API
port through the frontend and point a kubeconfig at `127.0.0.1`:

```sh
ssh -A -L 6443:r0.wg0:6443 rex@fishfinger.buetow.org
# then, in another shell, with a kubeconfig whose server is
# https://127.0.0.1:6443 (and tls-server-name r0.wg0.wan.buetow.org, since the
# API cert has that SAN — see install.md --tls-san):
kubectl --tls-server-name r0.wg0.wan.buetow.org get nodes
```
