# Hardware Reference

## Physical Nodes

Four **Beelink S12 Pro** mini-PCs with **Intel N100** CPUs. f0/f1/f2 each run a Rocky Linux bhyve VM as k3s nodes. f3 is a standalone bhyve host — not part of the k3s cluster.

### Specs (per node)

| Component | Spec |
|-----------|------|
| CPU | Intel N100 (Alder Lake-N), 4 cores/4 threads, up to 3.4 GHz |
| RAM | 16 GB DDR4 |
| Primary SSD | 500 GB M.2 (OS) |
| Secondary SSD | 2.5" slot (used for zdata pool on f0 and f1) |
| Ethernet | GbE (Realtek, interface `re0`) |
| USB | 4× USB 3.2 Gen2 |
| Power | ~8W idle per node; ~38.8W total (3 nodes + switch) under full load |
| Dimensions | 115×102×39 mm, 280 g |

### Wake-on-LAN

All three Beelinks support WoL (`WOL_MAGIC` on `re0`). Power is controlled by
**`f3sctl`** (`~/git/f3sctl`, installed on earth and on pi0/pi1):

```bash
f3sctl power status      # probe f0-f3 and the k3s nodes
f3sctl power on          # fans on, wake f0/f1/f2, un-mute Gogios
f3sctl power off         # ordered shutdown (f0 last), fans off, Gogios muted
f3sctl power f0 on|off   # one host only; f0-f3 each addressable
```

Shutdowns route through the HTTP API on pi0/pi1 by default, because the
restricted SSH key that may power a host off is pinned to those two hosts with
`from=` — so the same command works from a laptop off the LAN. Waking stays
local, since a magic packet is an unprivileged broadcast and must still work
when the API is unreachable.

The predecessor `wol-f3s` (bash) was removed from pi0–pi3 on 2026-08-09; a
copy remains on earth only. Its verbs are **not** accepted by `f3sctl` — old
spellings print a signpost to the replacement rather than being aliased, since
`all` meant "f0/f1/f2 but not f3" and was a standing trap.

MAC addresses:

| Host | MAC |
|------|-----|
| f0 | e8:ff:1e:d7:1c:ac |
| f1 | e8:ff:1e:d7:1e:44 |
| f2 | e8:ff:1e:d7:1c:a0 |
| f3 | e8:ff:1e:d7:f3:d7 |

BIOS requirements for WoL: enable "Wake on LAN", disable "ERP Support", enable "Power on by PCI-E".

### IP Addresses (LAN)

| Host | LAN IP | Hostname |
|------|--------|----------|
| f0 | 192.168.1.130 | f0.lan.buetow.org |
| f1 | 192.168.1.131 | f1.lan.buetow.org |
| f2 | 192.168.1.132 | f2.lan.buetow.org |
| f3 | 192.168.1.133 | f3.lan.buetow.org |

Static IPs configured at FreeBSD install time. Also in `/etc/hosts` on all nodes.

## Network

- **Switch**: TP-Link EAP615-Wall (OpenWrt Wi-Fi hotspot with 3 Ethernet ports)
- **Uplink**: 100 Mbit/s down / 50 Mbit/s up fiber (was previously 400 Mbit/s)
- UPS also connected to the switch so Wi-Fi stays up during power outages

## Physical Location

All infrastructure lives behind the TV (spouse acceptance factor). UPS is on the left, 3 Beelinks stacked on the right.
