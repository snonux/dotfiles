# Shelly Plug (Rack Fans)

A **Shelly Plug M Gen 3** powers the rack fans for the f3s rack. The f-hosts
switch it **on at boot**; `wol-f3s` switches it **on when waking all hosts** and
**off when shutting all hosts down**.

## Device

| Field | Value |
|-------|-------|
| Model | `S3PL-30110EU` (Shelly Plug M Gen 3) |
| ID / MAC | `shellyplugmg3-0892725e366c` / `0892725E366C` |
| IP | `192.168.1.28` (note: distinct from pi3 at `.128`) |
| Firmware | `1.8.99-plugmg3prod0` (app `PlugMG3`, gen 3) |
| Auth | **enabled** — HTTP digest, user `admin` |
| Max load | 16 A / ~3680 W |

The relay is `switch:0`. The open `/shelly` endpoint needs no auth; all `/rpc/*`
control and status calls require digest auth.

## Secret

The plug password is stored in plain files (first line of the file), **never in
git**:

| Host(s) | Location | Perms |
|---------|----------|-------|
| earth | `~/.shelly_plug` | `0600 paul` |
| pi0/pi1/pi2 | `~/.shelly_plug` (`/home/paul/.shelly_plug`) | `0600 paul` |
| f0/f1/f2/f3 | `/keys/shelly_plug.secret` (on the UFS USB key stick) | `0400 root:wheel` |

On the f-hosts the secret lives on the read-only `/keys` USB stick alongside the
ZFS encryption keys. Adding/updating it requires a temporary remount:

```sh
doas mount -u -o rw /keys
printf '%s\n' '<password>' | doas tee /keys/shelly_plug.secret >/dev/null
doas chmod 0400 /keys/shelly_plug.secret
doas chown root:wheel /keys/shelly_plug.secret
doas mount -u -o ro /keys
```

## HTTP RPC API

Base URL `http://192.168.1.28/rpc/<Method>`. With digest auth via curl:

```sh
pass=$(head -n1 ~/.shelly_plug)        # or /keys/shelly_plug.secret on f-hosts
A=(--digest -u admin:$pass)

curl -s "${A[@]}" "http://192.168.1.28/rpc/Switch.GetStatus?id=0"   # power/V/A/energy/temp
curl -s "${A[@]}" "http://192.168.1.28/rpc/Switch.Set?id=0&on=true"  # on
curl -s "${A[@]}" "http://192.168.1.28/rpc/Switch.Set?id=0&on=false" # off
curl -s "${A[@]}" "http://192.168.1.28/rpc/Switch.Toggle?id=0"       # toggle
curl -s "http://192.168.1.28/shelly"                                  # info (no auth)
```

`Switch.GetStatus` reports `output` (on/off), `apower` (W), `voltage`, `freq`,
`current`, `aenergy` (Wh total + per-minute), `ret_aenergy`, and internal
`temperature`. Useful config (`Switch.GetConfig`): `initial_state`
(`off`/`on`/`restore`/`match_input`), `auto_on`/`auto_off` timers, and safety
limits (`power_limit` 3000 W, `voltage_limit` 280 V, `current_limit` 13 A).

Beyond switching, the device also supports: Schedules, Webhooks, on-device JS
Scripts, KVS, Matter (enabled), MQTT/Cloud/KNX (disabled), BLE + BTHome gateway,
Wi-Fi, RGB status LED ring (`plugs_ui`), OTA updates, and virtual components.
List everything with `Shelly.ListMethods` and `Shelly.GetComponents?dynamic_only=false`.

## Boot-time auto-on (FreeBSD f-hosts)

Each f-host turns the plug on at boot via an rc.d service, so the fans always run
while any host is up. Source + runbook in the conf repo:
**`f3s/freebsd-hosts/shelly-fans/`** (`shelly-fans-on`, `shellyfans.rc`,
`README.md`).

- `/usr/local/sbin/shelly-fans-on` — helper that calls `Switch.Set?on=true`,
  retrying ~60s. **Sets `PATH` explicitly** (rc.d boots with a minimal PATH that
  excludes `/usr/local/bin` where `curl` lives — omitting this silently breaks it).
- `/usr/local/etc/rc.d/shellyfans` — `REQUIRE: NETWORKING f3skeys` (so `/keys` is
  mounted first), runs the helper backgrounded so a slow/unreachable plug never
  delays boot. Enable with `sysrc shellyfans_enable=YES`.
- Reads the password from `/keys/shelly_plug.secret`; missing stick = fans not
  switched (logged, non-fatal).

Install per host (scripts + `sysrc`), then put the secret on `/keys` (see above).
Verify: `doas service shellyfans start` then `grep shellyfans /var/log/messages`
(expect `Rack fans switched on`). Confirmed working via real reboot on f3.

**Deployment status:** f0, f2, f3 done. **f1 pending** (was offline / would not
wake via WoL when this was set up — deploy when it is back online).

## wol-f3s integration (earth + Pis)

`wol-f3s` (dotfiles `scripts/wol-f3s`; deployed to `/home/paul/scripts/wol-f3s`
on earth and `/usr/local/bin/wol-f3s` on pi0/pi1/pi2) controls the plug as part
of bulk power actions. On `pi0`/`pi1` (NetBSD) this needed: pkgsrc `bash`
(already present as a dependency of other packages) and pkgsrc `wol` installed,
the shebang changed from `#!/bin/bash` to `#!/usr/pkg/bin/bash` on the deployed
copy (dotfiles' own copy for earth/Linux stays as-is), `~/.shelly_plug` copied
over (missing on a fresh image), and `/etc/hosts` entries for `f0`–`f3`/`pi2`–`pi3`
(cross-Pi/host `.lan.buetow.org` resolution isn't reliable — same DNS gap
noted elsewhere in this skill). End-to-end verified from `pi0` (2026-07-03):
woke `f3` via WoL, toggled the shelly plug off/on, shut `f3` back down via
`wol-f3s shutdown-f3` — all worked. Note single-host `wol-f3s f3`/`shutdown-f3`
does **not** touch the shelly plug (only the bulk `all`/`shutdown-all` paths do).

- `wol-f3s` / `all` → `shelly_set true` **before** sending WoL packets (fans on).
- `wol-f3s shutdown-all` → `shelly_set false` **after** all hosts/Pis are down
  (fans off last).

The `shelly_set` helper reads the password from `~/.shelly_plug` and uses digest
auth; it no-ops gracefully if the file is missing. Partial actions (`shutdown`,
per-host wakes) leave the plug untouched.

## Standalone control script

`~/git/conf/playground/shelly-plug.sh` — convenience CLI:
`shelly-plug.sh [host] <status|on|off|toggle|info>`. Password from `SHELLY_PASS`
env or `~/.shelly_plug`; host defaults to `192.168.1.28`.
