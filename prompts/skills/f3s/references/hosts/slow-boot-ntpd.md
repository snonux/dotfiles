# Slow boot after a wake: ntpd_sync_on_start

## A woken f-host takes ~14 min to reach sshd — `ntpd_sync_on_start` (fixed 2026-08-09)

**Symptom.** After a WoL wake, the host answers ICMP within seconds but every
TCP port stays closed for about fourteen minutes. It looks exactly like the
single-user hang in [shutdown-hang.md](shutdown-hang.md), and it is not: `sysctl kern.boottime` and
`/var/log/messages` both show the kernel came up immediately. Only userland is
late.

Measured on f2, 2026-08-09: magic packet 09:32:25, `---<<BOOT>>---` 09:32:50,
sshd accepting at 09:46 — 14 minutes of ICMP-but-no-services.

**Cause.** `ntpd_sync_on_start="YES"` makes `rc.d/ntpd` run a *synchronous*
`ntpd -g -q` and block until the clock is stepped. `/etc/ntp.conf` lists only
the public pools:

```
pool 0.freebsd.pool.ntp.org iburst
pool 2.freebsd.pool.ntp.org iburst
```

and at boot those were failing to resolve — f2 logged
`ntpd: error resolving pool 0.freebsd.pool.ntp.org: Address family for hostname
not supported (1)` eight minutes in. `rcorder` puts `ntpd` at ~147 and `sshd`
at ~179, so every second ntpd waits is a second sshd does not exist.

**Fix applied to f0, f1, f2, f3:**

```sh
doas sysrc ntpd_sync_on_start=NO
```

This does not stop the clock being corrected. ntpd still starts, and the
default `ntpd_flags` include `-g`, which permits an arbitrarily large first
step once a server does answer — it simply no longer holds up the boot.

**No LAN NTP server is available as an alternative.** The gateway 192.168.1.1
does not answer UDP/123, and neither do pi0–pi3. Only f0 and f1 serve NTP, and
f-hosts cannot bootstrap time from each other because they all boot together.
If a local source is ever wanted, enable `ntpd` as a server on pi0/pi1 first.

**Two consequences worth knowing:**

1. `f3sctl` withholds `power off` for a host until **SSH** answers, not merely
   ping (see `clusterHostsUp` in `internal/httpapi/registry.go`). Before this
   fix that meant a freshly woken host could not be shut down for ~14 minutes.
2. The slow boot is what stranded the Gogios mute. `f3sctl`'s wake path waits
   for r0/r1/r2 before un-muting, bounded by `UnmuteTimeout` (was 600s). Hosts
   taking 14 min to reach sshd — plus guest boot on top — blew that budget, the
   un-mute gave up, and `/tmp/f3s_taken_down` was left in place on both
   gateways. See `f3s/references/` on Gogios blind spots.
