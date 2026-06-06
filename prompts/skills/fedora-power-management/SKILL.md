---
name: fedora-power-management
description: "Manage CPU/power profiles on this Fedora + GNOME laptop using tuned/tuned-ppd, including automatic switching to performance on AC and balanced on battery. Use when asked to change, inspect, or auto-switch power/CPU profiles, fix battery vs AC behavior, or troubleshoot tuned/tuned-ppd. Triggers on: power profile, power mode, CPU performance, battery vs AC, tuned, tuned-ppd, powerprofilesctl."
---

# Fedora Power Management

This Fedora 44 + GNOME laptop uses **tuned** with the **tuned-ppd** compatibility
layer (NOT `power-profiles-daemon`; `powerprofilesctl` is not installed). A custom
auto-switcher sets the profile based on AC vs battery.

## Stack facts

- `tuned.service` + `tuned-ppd.service` are active.
- `tuned-ppd` exposes 3 PPD profiles over the standard D-Bus name
  `org.freedesktop.UPower.PowerProfiles`: `power-saver`, `balanced`, `performance`.
- PPD→tuned mapping lives in `/etc/tuned/ppd.conf`:
  - `power-saver` → `powersave`
  - `balanced` → `balanced` (→ `balanced-battery` on battery, via `battery_detection=true`)
  - `performance` → `throughput-performance`
- tuned-ppd's `battery_detection` only swaps `balanced`→`balanced-battery`. It does
  **not** drop `performance`→`balanced` when unplugged — that is why the custom
  auto-switcher below exists.

## Inspect current state

```bash
tuned-adm active                      # actual tuned profile
busctl --system get-property org.freedesktop.UPower.PowerProfiles \
  /org/freedesktop/UPower/PowerProfiles \
  org.freedesktop.UPower.PowerProfiles ActiveProfile   # PPD profile
cat /sys/class/power_supply/BAT0/status               # Charging / Discharging / Full
```

## Set a profile manually

No `powerprofilesctl`; use D-Bus (works as the normal user via polkit):

```bash
busctl --system set-property org.freedesktop.UPower.PowerProfiles \
  /org/freedesktop/UPower/PowerProfiles \
  org.freedesktop.UPower.PowerProfiles ActiveProfile s performance   # or balanced / power-saver
```

## Automatic AC/battery switching (installed)

Switches to `performance` on external power and `balanced` on battery. AC detection
uses the battery `status` field (`Discharging` vs anything else) so it also covers
USB-C PD charging, with a Mains `online` fallback.

Three files make it work:

- `/usr/local/bin/auto-power-profile` — the switcher script (see
  `reference/auto-power-profile` for the exact contents).
- `/etc/systemd/system/auto-power-profile.service` — oneshot that runs the script;
  enabled (`multi-user.target`) so the correct profile applies at boot.
- `/etc/udev/rules.d/99-auto-power-profile.rules` — runs the service on any
  `power_supply` `change` event (plug/unplug).

The udev rule:

```
SUBSYSTEM=="power_supply", ACTION=="change", RUN+="/usr/bin/systemctl --no-block start auto-power-profile.service"
```

The systemd unit `ExecStart=/usr/local/bin/auto-power-profile`, `Type=oneshot`,
`After=tuned.service tuned-ppd.service`, `WantedBy=multi-user.target`.

### Reinstall / restore

Copy `reference/auto-power-profile`, `reference/auto-power-profile.service`, and
`reference/99-auto-power-profile.rules` into place, then:

```bash
sudo install -m 0755 auto-power-profile          /usr/local/bin/auto-power-profile
sudo install -m 0644 auto-power-profile.service  /etc/systemd/system/auto-power-profile.service
sudo install -m 0644 99-auto-power-profile.rules /etc/udev/rules.d/99-auto-power-profile.rules
sudo systemctl daemon-reload
sudo systemctl enable auto-power-profile.service
sudo udevadm control --reload-rules
sudo systemctl start auto-power-profile.service   # apply now
```

### Verify

```bash
journalctl -u auto-power-profile.service -f       # watch as you plug/unplug
sudo udevadm trigger --subsystem-match=power_supply --action=change  # force a run
```

### Change the target profiles

Edit `AC_PROFILE` / `BATTERY_PROFILE` at the top of
`/usr/local/bin/auto-power-profile` (valid values: `performance`, `balanced`,
`power-saver`), then `sudo systemctl start auto-power-profile.service`.

### Disable / remove

```bash
sudo systemctl disable --now auto-power-profile.service
sudo rm /usr/local/bin/auto-power-profile \
        /etc/systemd/system/auto-power-profile.service \
        /etc/udev/rules.d/99-auto-power-profile.rules
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
```
