# Shelly Plug (Rack Fans)

A **Shelly Plug M Gen 3** powers the rack fans for the f3s rack. The f-hosts
switch it **on at boot** (rc.d `shellyfans`, `shellyfans_enable="YES"`);
`f3sctl` switches it **on when waking all hosts** and **off when shutting all
hosts down**.

That boot-time service is also the safety net for a host that powers itself
back on after the fans were switched off — it restores the fans without
anyone intervening. See `console-jetkvm-shutdown.md` §2a.

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

## f3sctl integration (earth + pi0/pi1)

`f3sctl` (`~/git/f3sctl`) owns the plug during bulk power actions, and also
exposes it on its own so the fans can be controlled without powering anything:

```bash
f3sctl fans status
f3sctl fans on
f3sctl fans off [--force]
```

- `f3sctl power on` → plug **on before** sending WoL packets (fans on first).
- `f3sctl power off` → plug **off after** every selected host has powered down
  (fans off last).
- Per-host actions (`f3sctl power f1 off`) leave the plug **untouched** — one
  host going down does not mean the rack is idle.

**The fans-off guard.** Switching the plug off while any f-host still answers
ICMP is refused: `409` from the API, a refusal from the CLI, unless `--force` /
`force=true`. The rack fans cool whatever is running, so cutting them under a
live rack is a thermal risk rather than a preference. In the API this is
expressed as a `force` **field** on the `fans-off` action, present only while a
host is up — so a client renders a confirmation toggle from what it was given
and never hard-codes the rule.

Reads are verified, not assumed: every set is followed by a `Switch.GetStatus`
read-back, because a digest-auth failure still returns a 200 with a body. If
the plug cannot be read at all, `f3sctl` reports the fans as **unknown**, never
as off — and withholds both fan actions, since there is no way to report
truthfully whether they worked.

Credentials come from `/var/db/f3sctl/shelly_plug` (the CGI, owned `_httpd`),
`/keys/shelly_plug.secret` (f-hosts) or `~/.shelly_plug` (earth), first
readable wins.

The predecessor `wol-f3s` was removed from pi0–pi3 on 2026-08-09 (earth keeps a
copy). It needed pkgsrc `bash`, pkgsrc `wol`, a patched shebang and `/etc/hosts`
entries on each Pi; `f3sctl` is a static Go binary with none of those
dependencies — WoL is sent natively as a UDP broadcast.

## Standalone control script

`~/git/conf/playground/shelly-plug.sh` — convenience CLI:
`shelly-plug.sh [host] <status|on|off|toggle|info>`. Password from `SHELLY_PASS`
env or `~/.shelly_plug`; host defaults to `192.168.1.28`.
