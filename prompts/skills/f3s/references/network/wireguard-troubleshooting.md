# WireGuard troubleshooting

## Troubleshooting: `reload` vs `restart` When Adding New Peers

`service wireguard reload` (used by the mesh generator) updates peer config but **does NOT add routes** for new peers. After adding a new host to the mesh, the other hosts need a full restart to get the new routes:

```sh
# On each existing host that had a new peer added via reload:
doas service wireguard restart
```

**Symptom**: WireGuard handshake succeeds (both sides show `latest handshake`) but TCP/ICMP traffic doesn't flow — confirmed by `netstat -rn | grep 192.168.2.NNN` returning no results.

## Troubleshooting: Regenerated Keypair Breaks the Tunnel

If a host's wg0 PrivateKey (and PSKs) are regenerated out-of-band (e.g. OS reinstall) but the peer configs on the other side are not updated, handshakes silently fail: `wg show` shows `0 B received` on the client and `endpoint: (none), rx=0` for that peer on the gateway, even though packets leave the client (confirmed with `tcpdump` on the wifi interface). WireGuard drops initiations it cannot authenticate and emits nothing, so the symptom is one-way traffic with no replies.

All three must match on both sides:
- the client's **PublicKey** as configured in the gateway's peer block,
- the gateway's **PublicKey** as configured in the client's peer block (must equal `wg show wg0 public-key` on the gateway),
- the per-pair **PresharedKey** (must be identical on both sides).

When fixing this by hand, also update the `wireguardmeshgenerator` `keys/` directory (`keys/<host>/priv.key`, `pub.key`, `keys/psk/<sorted_pair>.key`) so a regen reproduces the live configs — otherwise the next `--generate`/`--install` reverts the fix. This is tracked as the generator `+credentials` task.

## Troubleshooting: Dual `0.0.0.0/0` on Roaming Clients

A roaming client config that gives `AllowedIPs = 0.0.0.0/0, ::/0` to **both** gateway peers (as the generator currently does for `gateway: true`) is only partially functional: wg-quick can install only one default route, so the second peer silently ends up with `allowed ips: (none)` in the running config and is **not** a real failover. On `earth`, `sudo wg show` shows fishfinger with `0.0.0.0/0, ::/0` and blowfish with `(none)`.

Consequence: all return traffic to earth must go via fishfinger (the peer earth actually accepts traffic from). This is why the direct-SSH return route is added to the fishfinger peer only. A proper fix (single primary gateway with failover, or `Table = off` with policy routing) is tracked as the generator `+roamingFailover` task.
