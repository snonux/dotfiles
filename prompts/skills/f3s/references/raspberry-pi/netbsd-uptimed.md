# NetBSD Pis: uptimed and goprecords upload

## uptimed (built from source — no prebuilt package)

**No aarch64 binary package exists** in pkgsrc for `uptimed` on any branch
checked (10.0, 10.1, 11.0, 9.4). Build from upstream instead — small C
project, NetBSD base already has `gcc`/`make`:

```sh
pkgin -y install autoconf automake libtool pkg-config
cd /tmp
curl -sLO https://github.com/rpodgorny/uptimed/archive/refs/tags/v0.4.7.tar.gz
tar xzf v0.4.7.tar.gz && cd uptimed-0.4.7
PATH=/usr/pkg/bin:$PATH ./autogen.sh
PATH=/usr/pkg/bin:$PATH ./configure --prefix=/usr/pkg --sysconfdir=/etc
PATH=/usr/pkg/bin:$PATH make
doas env PATH=/usr/pkg/bin:/usr/bin:/bin:/usr/sbin:/sbin make install
```

Installs `uptimed` to `/usr/pkg/sbin`, `uprecords` to `/usr/pkg/bin`, and uses
`/var/spool/uptimed/records` (hardcoded upstream, not an OS convention thing).

**Before first start**, write `/etc/uptimed.conf` with `LOG_MAXIMUM_ENTRIES=0`
(keep forever) plus milestone lines. If restoring a backed-up uptime history,
seed **both** `records` and `records.old` with the same content:

```sh
doas cp <backed-up-records-file> /var/spool/uptimed/records
doas cp <backed-up-records-file> /var/spool/uptimed/records.old   # both, not just one
doas /usr/sbin/chown root:wheel /var/spool/uptimed/records /var/spool/uptimed/records.old
```

**Critical bug to know about**: `read_records()` in `libuptimed/urec.c`
unconditionally sets `useold = -1` ("no useable database found") if
`records.old` doesn't exist yet — **regardless of whether the primary
`records` file is valid**. Seeding only `records` and starting the daemon
loses the imported history immediately (it gets shunted to a fresh
`records.old` on the first periodic rewrite, then overwritten again 60s
later). Seed **both** files with the same content before the first start.

Write a custom `/etc/rc.d/uptimed` (upstream ships a Linux-init `etc/rc.uptimed`,
not usable directly):

```sh
# PROVIDE: uptimed
# REQUIRE: NETWORKING ntpdate
# KEYWORD: shutdown

command="/usr/pkg/sbin/uptimed"
pidfile="/var/run/uptimed.pid"
command_args="-p ${pidfile}"
```

These Raspberry Pis have no hardware RTC. NetBSD initializes the wall clock
from the root filesystem timestamp, which can be stale after power-off. Merely
starting `ntpd` is not a synchronization barrier, so enable the synchronous
boot-time correction in `/etc/rc.conf`:

```sh
ntpdate=YES
```

The explicit `ntpdate` requirement above ensures that uptimed starts only after
the clock has been set from the network. Verify the boot ordering with:

```sh
/sbin/rcorder /etc/rc.d/* | egrep '/(NETWORKING|ntpdate|ntpd|uptimed)$'
```

The expected order is `NETWORKING`, `ntpdate`, `ntpd`, then `uptimed`. This was
deployed and reboot-tested one node at a time on both pi0 and pi1 on
**2026-07-16**. `ntpdate` corrected pi0 by 12.29 seconds and pi1 by 12.68
seconds before uptimed started; their new current records had the correct boot
times, both webservers returned HTTP 200, and no historical record repair was
necessary.

Run `uptimed -b` once (creates the boot ID), enable with `uptimed=YES`.

## goprecords upload

```sh
kubectl exec -n services deployment/goprecords -- \
	goprecords --create-client-key <host> -stats-dir=/data/stats
```
(from a machine with cluster access — this can occasionally 502 if the
apiserver's exec proxy can't reach whichever k3s node the pod landed on; just
retry, it's a transient networking issue, not a token problem.)

Deploy `goprecords-upload-client.sh` (from `~/git/goprecords/scripts/`,
already POSIX/generic and already handles `/var/spool/uptimed/records` and a
NetBSD `dmesg.boot`/`sysctl` fallback for `os.txt`/`cpuinfo.txt` — no changes
needed) to **`/usr/pkg/bin/`** to match the pre-baked crontab's path, token at
`/etc/goprecords-upload.token` (`0600`), `GOPRECORDS_HOST=<host>`.

`curl` and `uprecords` need to be resolvable via whatever `PATH` the cron
entry sets — test with that exact `PATH` before trusting a manual test run
under plain `doas` (which won't have it).
