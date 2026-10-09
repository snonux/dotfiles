# JetKVM on the f-hosts

A JetKVM (KVM-over-IP) is attached to **each of f0, f1, f2, f3** (USB + HDMI); see
the inventory below. It enumerates on the FreeBSD USB bus as vendor `0x1d6b`, product
`0x0104` — HID interfaces (keyboard/tablet/mouse), audio, and mass storage (virtual
media). Older firmware reported the product string as `Multifunction Composite Gadget
Linux Foundation`; firmware 0.5.9 reports `JetKVM USB Emulation Device`, so match on
the vendor/product IDs rather than a name. The gadget's USB serial number is empty on
all four, so a host cannot tell *which* JetKVM it has from the USB side.

## JetKVM inventory, login and remote probing (verified 2026-10-06)

**The IPs are DHCP leases and may differ next time — the MAC and device ID are the
stable identifiers.** Re-discover before trusting the IP column (command below), and
match a unit by its MAC or by `getDeviceID` / `GET /device`, never by IP alone.

| MAC (stable) | Device ID / hostname suffix (stable) | Attached to | LAN IP on 2026-10-06 (DHCP) | HDMI capture 2026-10-06 |
|---|---|---|---|---|
| 30:52:53:03:57:38 | `46793b0d4c8d45d` | **f2** (proven, see below) | 192.168.1.151 | **no signal / `no_lock`** |
| 30:52:53:08:97:97 | `e10a0883debf7d4a` | not yet mapped | 192.168.1.158 | 1920x1080 @ 60 |
| 30:52:53:06:8b:21 | `f72978d7f87aa969` | not yet mapped | 192.168.1.191 | 1920x1080 @ 60 |
| 30:52:53:04:a4:4b | `cee6ab4df2f88754` | not yet mapped | 192.168.1.198 | 1920x1080 @ 60 |

All four run firmware app `0.5.9` / system `0.2.8`, and their mDNS/DHCP hostname is
`jetkvm-<device id>`. There are no DNS names for them: `jetkvm*.f3s.lan.buetow.org`
resolves, but only through the Pi-hole wildcard (to the storage VIP), so ignore it.

**Discovery** (from a machine on the LAN; sweeps the /24 for web UIs titled `JetKVM`,
then prints each hit with its MAC so it can be matched to the table):

```sh
for i in $(seq 1 254); do
  ( curl -s -m 3 http://192.168.1.$i/ | grep -q -i '<title>JetKVM' && echo 192.168.1.$i ) &
done | sort -t. -k4 -n | while read ip; do ip neigh show "$ip"; done
```

The host references refer to units by the IP they had on 2026-10-06 (`.151`
etc.) as shorthand; translate through the MAC if the leases have moved. A static DHCP
reservation per MAC on the router would make the IPs stable, but none is set up.

**Password.** Since 2026-10-06 all four share one local password, stored in
`~/.jetkvm` on the laptop (before that they had three different ones, which is why
earlier notes claimed the stored password "is rejected"). Never write it into this
skill's files.

**The JetKVMs CAN be driven without a browser** (an earlier note here said otherwise):

- `GET  http://<ip>/device/status` — unauthenticated, returns `{"isSetup":true}`.
- `POST http://<ip>/auth/login-local` with `{"password": "..."}` — plain HTTP works;
  sets the auth cookie. `GET /device` then returns the device ID and auth mode.
- `PUT  http://<ip>/auth/password-local` with `{"oldPassword","newPassword"}` (needs the
  login cookie) changes the password.
- Everything else (video state, USB state, EDID, reboot, USB emulation on/off) is
  JSON-RPC 2.0 over the WebRTC data channel named `rpc`. Signaling is the websocket
  `/webrtc/signaling/client`: send `{"type":"offer","data":{"sd":<base64 JSON SDP>}}`,
  receive `{"type":"answer","data":<base64 JSON SDP>}`. The legacy
  `POST /webrtc/session` returns 404 on this firmware.

[`scripts/jetkvm-probe.py`](../../scripts/jetkvm-probe.py) does all of that read-only
(login, WebRTC session, `getVideoState`, `getUSBState`, versions, network state) for
any number of IPs; it needs `aiortc` + `aiohttp` in a throwaway venv (see its
docstring). It reports the device's own view of the HDMI input — the Python client
does not decode the video stream, so it is not a screenshot. To actually see or type
on a console, use the web UI in a browser.

**Mapping a JetKVM to its f-host.** Call RPC `setUsbEmulationState {"enabled": false}`,
wait a few seconds, then `{"enabled": true}`, and see which host logs the gadget
re-attaching (`grep 'JetKVM USB Emulation' /var/log/messages`, readable without root).
This detaches the emulated keyboard/mouse from that host for a few seconds and nothing
else. Done for `.151` on 2026-10-06: only f2 logged it. The other three still need it.

### f2's JetKVM (.151) gets no usable HDMI signal (open, 2026-10-06)

`.151` reported `no_signal` while the other three captured 1920x1080 @ 60. After
rebooting that JetKVM (RPC `reboot`) the error changed to `no_lock` and stayed there:
it now sees a signal but cannot lock onto it. Not the host's configuration: f2 logs
`VT(efifb): resolution 1920x1080` with the same `efi_max_resolution="1080p"` as the
three working hosts, and `.151` presents the same default EDID (`JetKVM v1`). f2 got
1080p from the firmware at boot, so the EDID read over the cable works; only the video
signal does not lock. That leaves the physical path — HDMI cable/seating, f2's HDMI
port, or that JetKVM unit. Next step is hands-on: reseat or swap the HDMI cable, or
swap `.151` with a known-good JetKVM to see whether the fault follows the unit or
stays with f2. Not tried: rebooting f2 to make the firmware re-initialise the output.
Until fixed, **f2 has no remote console** (USB keyboard/mouse still work blind).

## JetKVM virtual USB drive stalled every boot for ~6 minutes (fixed 2026-09-26)

The JetKVM's mass-storage function (USB `0x1d6b:0x0104`, "JetKVM USB Emulation
Device") never answers the CAM probe, so each f-host boot sat at `Root mount
waiting for: CAM` until ~370s. gonf `freebsd_loader_conf` now sets
`hw.usb.quirk.0="0x1d6b 0x0104 0x0000 0xffff UQ_MSC_IGNORE"` on f0-f3: only the
mass-storage interface is ignored (keyboard/mouse keep working; the /keys USB
sticks have other IDs). Verified on f3: sshd at 22s instead of 391s. To install
from a JetKVM-attached ISO, remove the line (or override at the loader prompt:
`unset hw.usb.quirk.0`) for that boot.
