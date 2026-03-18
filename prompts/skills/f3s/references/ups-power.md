# UPS and Power Protection

## Hardware

**APC Back-UPS BX750MI** (750VA / 410W)

- ~65 minutes runtime for the f3s cluster at idle load
- USB connectivity to `f0` for monitoring
- 4 outlets: 3× Beelinks + 1× TP-Link switch
- Silent (no noise when on mains power)
- User-replaceable batteries

## FreeBSD: `apcupsd` on f0 (USB master)

`f0` is directly connected to the UPS via USB.

### Detection
```
ugen0.2: <American Power Conversion Back-UPS BX750MI> at usbus0
```

### Install
```sh
doas pkg install apcupsd
doas sysrc apcupsd_enable=YES
doas service apcupsd start
```

### Config (`/usr/local/etc/apcupsd/apcupsd.conf` diff from sample)
```
UPSCABLE usb
UPSTYPE usb
DEVICE          # (empty — auto-detect USB)
BATTERYLEVEL 5  # shutdown when battery < 5%
MINUTES 3       # shutdown when < 3 min runtime left
```

### Status check
```sh
apcaccess          # full status
apcaccess -p TIMELEFT  # remaining minutes
```

## `apcupsd` on f1, f2, and f3 (network clients)

`f1`, `f2`, and `f3` query the UPS status from `f0` over the network (port 3551).
They are configured to shut down *earlier* than `f0` to avoid losing the UPS status feed.

### Config diff from sample (f1 and f2)
```
UPSCABLE ether
UPSTYPE net
DEVICE f0.lan.buetow.org:3551
BATTERYLEVEL 10   # higher than f0's 5%
MINUTES 6         # higher than f0's 3 min
```

### Enable
```sh
doas sysrc apcupsd_enable=YES
doas service apcupsd start
apcaccess | grep Percent  # verify
```

## Shutdown Order

On power failure, the expected graceful shutdown sequence is:
1. **f1, f2, and f3** — shut down first (BATTERYLEVEL 10, MINUTES 6)
2. **f0** — shuts down last (BATTERYLEVEL 5, MINUTES 3)

This ensures f1/f2/f3 can still reach f0's apcupsd to learn the UPS status before f0 shuts down.

## Logs

```sh
grep apcupsd /var/log/daemon.log
```
