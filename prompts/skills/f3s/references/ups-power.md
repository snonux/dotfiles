# UPS and Power Protection

## Hardware

**APC Back-UPS BX750MI** (750VA / 410W)

- ~65 minutes runtime estimated when new; `apcaccess` reports ~27 min at 17 % load (2026-09)
- USB connectivity to `f0` for monitoring
- 4 outlets: 3× Beelinks + 1× TP-Link switch
- Silent (no noise when on mains power)
- User-replaceable batteries

## `apcupsd` on the f-hosts (managed by gonf)

Since 2026-09-25 apcupsd's config is managed by gonf in `~/git/conf`
(`gonf/freebsd/apcupsd.go`, template and client script in
`f3s/freebsd-hosts/apcupsd/`, per-host `freebsd.UPS` data in
`gonf/cluster/cluster.go`). Do not hand-edit `apcupsd.conf`; deploy with:

```sh
./gonf.sh -n cluster freebsd-hosts freebsd_apcupsd_client_events freebsd_apcupsd_config
./gonf.sh cluster freebsd-hosts freebsd_apcupsd_client_events freebsd_apcupsd_config
```

`freebsd_apcupsd_config` restarts apcupsd only when the file changed.

| Host | Role | `UPSCABLE`/`UPSTYPE` | `DEVICE` | `NISIP` | `BATTERYLEVEL` / `MINUTES` |
|---|---|---|---|---|---|
| f0 | USB master + NIS server | usb / usb | *(empty, USB autodetect)* | `192.168.1.130` (LAN only) | 5 % / 3 min |
| f1, f2, f3 | net clients of f0 | ether / net | `192.168.1.130:3551` | `127.0.0.1` (local `apcaccess` only) | 10 % / 6 min |

Detection on f0: `ugen0.2: <American Power Conversion Back-UPS BX750MI> at usbus0`.
Fresh host: `doas pkg install apcupsd && doas sysrc apcupsd_enable=YES`, then
the gonf deploy (it installs the package and starts the service too).

### Status check
```sh
apcaccess                # full status (reads NISIP/NISPORT from apcupsd.conf)
apcaccess -p TIMELEFT    # remaining minutes
```
Clients show `STATUS : ONLINE SLAVE` and `MASTER : 192.168.1.130:3551`.

### Runtime and battery age

On 2026-09-25 `apcaccess` reported `TIMELEFT 27.1 Minutes` at `LOADPCT 17`
(well below the ~65 min estimated when the UPS was new), `SELFTEST OK`, and
f0 got one "battery needs changing NOW" mail on 2025-08-30.
`BATTDATE` shows `2001-01-01`: the battery install date was never set, so
battery age cannot be tracked. To set it (not done yet, needs a short
apcupsd outage on f0, and f1-f3 lose their feed meanwhile):

```sh
doas service apcupsd stop
doas apctest            # menu 4) "View/Change battery date": enter the
                        # install date as MM/DD/YYYY, then Q to quit.
                        # NEVER pick 1) "Test kill UPS power" (cuts all outlets).
doas service apcupsd start
apcaccess -p BATTDATE
```

The UPS (and its battery) went into service around 2024-12 (a saved
`apctest` session in `/usr/local/etc/apcupsd/apctest.output` on f0 is dated
2024-12-03; menu 5 shows the manufacturing date). If the firmware ignores
the write and `BATTDATE` stays `2001-01-01`, record the battery date here.

## Shutdown Order

On power failure, the expected graceful shutdown sequence is:
1. **f1, f2, and f3** — shut down first (BATTERYLEVEL 10, MINUTES 6)
2. **f0** — shuts down last (BATTERYLEVEL 5, MINUTES 3)

The threshold difference is deliberate: f1/f2/f3 still reach f0's apcupsd to
learn the UPS status while they shut down, and f0, which owns the USB link,
goes last. With the ~27 min runtime measured in 2026-09 the clients shut down
around 6 min remaining and f0 around 3 min.

## "Communications with UPS lost/restored" (expected, not flapping)

A net client loses its UPS feed whenever f0's apcupsd is not running: every
nightly power-off, every morning power-on (the clients' apcupsd polls a few
seconds before f0's is up, then "restored"), every daytime f0 reboot, and a
client that stays up while f0 is off logs "lost" again every 10 minutes. In
the 2026-09-25 audit every lost/restored pair on f1-f3 matched an f0
shutdown/boot in `last reboot shutdown`; there was no network flapping.
The stock `commfailure`/`commok` scripts mailed root each time (~900 mails on
f2), so on f1-f3 gonf replaces them with a script that exits 99 (no mail, no
wall). The events stay in syslog and `/var/log/apcupsd.events`. f0 keeps the
stock mailing scripts: there a lost event means the USB link to the UPS broke.

## Logs

```sh
tail /var/log/apcupsd.events     # start/stop, lost/restored, power events
grep apcupsd /var/log/messages   # same events via syslog (rotated hourly on f-hosts)
```
