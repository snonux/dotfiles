# Shelly Plugs (f3s)

Two **Shelly Plug M Gen 3** (`S3PL-30110EU`) devices on the LAN. Same model,
same digest password, same RPC shape — different roles.

| Name | IP | Hostname | Role |
|------|----|----------|------|
| **shelly1** | `192.168.1.28` | `shelly1.lan` | Rack fans |
| **shelly2** | `192.168.1.29` | `shelly2.lan` | AC for the f-hosts (f0–f3) |

(`.28` is distinct from pi3 at `.128`.)

## Devices

| Field | shelly1 | shelly2 |
|-------|---------|---------|
| ID / MAC | `shellyplugmg3-0892725e366c` / `0892725E366C` | `shellyplugmg3-0892725f8a04` / `0892725F8A04` |
| Firmware | `2.0.0` (app `PlugMG3`) | `1.8.99-plugmg3prod0` (app `PlugMG3`) |
| Auth | digest, user `admin` | same |
| Wi‑Fi | `www_irregular_ninja`, static IP as above | same SSID / static |
| `initial_state` | `off` | `off` |
| Safety limits | 3000 W / 280 V / 13 A | same |
| Cloud / MQTT | off | off |
| Matter | on | on |
| BLE / BLE-RPC | off | off |
| Max load | 16 A / ~3680 W | same |

Relay is always `switch:0`. Open `/shelly` needs no auth; all `/rpc/*` calls
need digest auth.

## Secret

One shared password (first line of the file), **never in git**:

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

Base URL `http://<host>/rpc/<Method>` — use `shelly1` / `shelly2` (or the
dotted IP). Digest auth via curl:

```sh
pass=$(head -n1 ~/.shelly_plug)        # or /keys/shelly_plug.secret on f-hosts
A=(--digest -u admin:$pass)
H=shelly1                              # or shelly2 / 192.168.1.29

curl -s "${A[@]}" "http://$H/rpc/Switch.GetStatus?id=0"   # power/V/A/energy/temp
curl -s "${A[@]}" "http://$H/rpc/Switch.Set?id=0&on=true"  # on
curl -s "${A[@]}" "http://$H/rpc/Switch.Set?id=0&on=false" # off
curl -s "${A[@]}" "http://$H/rpc/Switch.Toggle?id=0"       # toggle
curl -s "http://$H/shelly"                                  # info (no auth)
```

`Switch.GetStatus` reports `output` (on/off), `apower` (W), `voltage`, `freq`,
`current`, `aenergy` (Wh total + per-minute), `ret_aenergy`, and internal
`temperature`. Useful config (`Switch.GetConfig`): `initial_state`
(`off`/`on`/`restore`/`match_input`), `auto_on`/`auto_off` timers, and the
safety limits above. (Power-count fields appear on fw `2.0.0+` only.)

Beyond switching, the devices also support Schedules, Webhooks, on-device JS
Scripts, KVS, Matter, MQTT/Cloud/KNX (disabled here), BLE + BTHome gateway,
Wi-Fi, RGB status LED ring (`plugs_ui`), OTA updates, and virtual components.
List everything with `Shelly.ListMethods` and
`Shelly.GetComponents?dynamic_only=false`.

## Standalone control script

`~/git/conf/playground/shelly-plug.sh` — convenience CLI:
`shelly-plug.sh [host] <status|on|off|toggle|info>`. Password from `SHELLY_PASS`
env or `~/.shelly_plug`; host defaults to `192.168.1.28` (shelly1). Pass
`shelly2` / `192.168.1.29` for the f-host plug.

## shelly1 — Rack fans

Powers the rack fans. The f-hosts switch it **on at boot** (rc.d `shellyfans`);
`f3sctl` switches it **on when waking** and **off when shutting all hosts
down**. That boot-time service is also the safety net for a host that powers
itself back on after the fans were switched off. See
`console-jetkvm-shutdown.md` §2a.

### Boot-time auto-on (FreeBSD f-hosts)

Source + runbook in the conf repo: **`f3s/freebsd-hosts/shelly-fans/`**
(`shelly-fans-on`, `shellyfans.rc`, `README.md`).

- `/usr/local/sbin/shelly-fans-on` — calls `Switch.Set?on=true` on **shelly1**,
  retrying ~60s. **Sets `PATH` explicitly** (rc.d boots with a minimal PATH that
  excludes `/usr/local/bin` where `curl` lives — omitting this silently breaks it).
- `/usr/local/etc/rc.d/shellyfans` — `REQUIRE: NETWORKING f3skeys` (so `/keys` is
  mounted first), runs the helper backgrounded so a slow/unreachable plug never
  delays boot. Enable with `sysrc shellyfans_enable=YES`.
- Reads the password from `/keys/shelly_plug.secret`; missing stick = fans not
  switched (logged, non-fatal).

Install per host (scripts + `sysrc`), then put the secret on `/keys` (see
Secret). Verify: `doas service shellyfans start` then
`grep shellyfans /var/log/messages` (expect `Rack fans switched on`). Confirmed
working via real reboot on f3.

**Deployment status:** f0, f2, f3 done. **f1 pending** (was offline / would not
wake via WoL when this was set up — deploy when it is back online).

### f3sctl integration (earth + pi0/pi1)

`f3sctl` (`~/git/f3sctl`) owns **shelly1** during bulk power actions, and also
exposes it on its own:

```bash
f3sctl fans status
f3sctl fans on
f3sctl fans off [--force]
```

- `f3sctl power on` → shelly1 **on before** sending WoL packets (fans on first).
- `f3sctl power off` → shelly1 **off after** f0/f1/f2 have powered down (fans
  off last).
- Per-host actions (`f3sctl power f1 off`) leave shelly1 **untouched** — one
  host going down does not mean the rack is idle.

**The fans-off guard is scoped to f0/f1/f2 only.** Switching shelly1 off while
any of f0, f1 or f2 still answers ICMP is refused: `409` from the API, a
refusal from the CLI, unless `--force` / `force=true`. f3 is deliberately
excluded — it is racked separately and shelly1 does not cool it, so f3's power
state has no bearing on whether cutting the fans is safe. A bare
`f3sctl power off` (which never touches f3) therefore switches the fans off as
soon as f0/f1/f2 go quiet, even while f3 keeps running. In the API this is a
`force` **field** on the `fans-off` action, present only while an f0/f1/f2 host
is up — so a client renders a confirmation toggle from what it was given and
never hard-codes the rule.

Reads are verified, not assumed: every set is followed by a `Switch.GetStatus`
read-back, because a digest-auth failure still returns a 200 with a body. If
the plug cannot be read at all, `f3sctl` reports the fans as **unknown**, never
as off — and withholds both fan actions.

Credentials come from `/var/db/f3sctl/shelly_plug` (the CGI, owned `_httpd`),
`/keys/shelly_plug.secret` (f-hosts) or `~/.shelly_plug` (earth), first
readable wins.

The predecessor `wol-f3s` was removed from pi0–pi3 on 2026-08-09 (earth keeps a
copy). `f3sctl` is a static Go binary; WoL is sent natively as a UDP broadcast.

## shelly2 — f-host AC

Hard-cuts / restores mains to the f-hosts (f0–f3) and their JetKVM switches.
Same auth and RPC as shelly1. Wired into `f3sctl` as an **independent** switch
— never flipped by `power on` / `power off` / boot:

```bash
f3sctl ac status
f3sctl ac on
f3sctl ac off [--force]
```

API: `GET /ac`, `POST /ac/on`, `POST /ac/off` (actions `ac-on` / `ac-off`).
`ac off` refuses while any of f0–f3 may still answer ICMP (f3 included),
unless `--force` / `force=true`. Cutting AC without a prior graceful shutdown
risks ZFS / bhyve damage; treat a forced cut as last-resort or post-shutdown.

Standalone script still works for ad-hoc use:

```sh
~/git/conf/playground/shelly-plug.sh shelly2 status|on|off|toggle|info
```
