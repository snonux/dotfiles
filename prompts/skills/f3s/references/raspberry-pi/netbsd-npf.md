# NetBSD Pis: npf firewall

## Firewall — npf, not firewalld

```
$ext_if = "mue0"

group "external" on $ext_if {
	pass stateful out final all
	pass stateful in final family inet4 proto tcp to $ext_if port 22
	pass stateful in final family inet4 proto tcp to $ext_if port 80
	pass stateful in final family inet4 proto tcp to $ext_if port 2222
	pass stateful in final family inet4 proto icmp all
}

group "wireguard" on tun0 {
	pass stateful out final all
	pass stateful in final family inet4 all
	pass stateful in final family inet6 all
}

group default {
	pass final on lo0 all
	block all
}
```

Port 2222 is dserver (DTail) — see [dtail-package.md](../pkgrepo/dtail-package.md)
for the install steps.

`family inet4`/`inet6` must be explicit on multi-family interfaces or
`npfctl validate` fails with "address family mismatch". `proto <name>` must
be followed by `all` or a `from`/`to` clause, or it's a syntax error — e.g.
`proto icmp` alone fails, `proto icmp all` doesn't. Don't forget the ICMP
rule: without it, ping-dependent tooling (e.g. the `snonux` publishing
tool's reachability pre-check) silently breaks while SSH/HTTP keep working
fine.

Sequence carefully to avoid locking yourself out over SSH:

```sh
doas npfctl validate           # syntax-check first
doas npfctl reload             # loads config, does NOT enable filtering yet
doas npfctl start               # enables filtering
# from a FRESH ssh connection (not the one you're already in), confirm:
#   - ssh still connects
#   - curl http://localhost/ still works
doas sh -c 'echo npf=YES >> /etc/rc.conf'   # only after confirming the above
```

If you get a JIT warning (`error loading the bpfjit module... Operation not
permitted`) — harmless, just means `kern.securelevel` blocks loading that
optional performance module; filtering still works, just slightly slower
packet matching.
