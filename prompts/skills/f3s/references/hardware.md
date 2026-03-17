# Hardware Reference

## Physical Nodes

Three **Beelink S12 Pro** mini-PCs with **Intel N100** CPUs.

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

All three Beelinks support WoL (`WOL_MAGIC` on `re0`). The script `~/bin/wol-f3s` on the Fedora laptop (`earth`) controls power:

```bash
wol-f3s          # wake all three
wol-f3s f0       # wake only f0
wol-f3s shutdown # graceful SSH shutdown of all three
```

MAC addresses:

| Host | MAC |
|------|-----|
| f0 | e8:ff:1e:d7:1c:ac |
| f1 | e8:ff:1e:d7:1e:44 |
| f2 | e8:ff:1e:d7:1c:a0 |

BIOS requirements for WoL: enable "Wake on LAN", disable "ERP Support", enable "Power on by PCI-E".

### IP Addresses (LAN)

| Host | LAN IP | Hostname |
|------|--------|----------|
| f0 | 192.168.1.130 | f0.lan.buetow.org |
| f1 | 192.168.1.131 | f1.lan.buetow.org |
| f2 | 192.168.1.132 | f2.lan.buetow.org |

Static IPs configured at FreeBSD install time. Also in `/etc/hosts` on all nodes.

## Network

- **Switch**: TP-Link EAP615-Wall (OpenWrt Wi-Fi hotspot with 3 Ethernet ports)
- **Uplink**: 100 Mbit/s down / 50 Mbit/s up fiber (was previously 400 Mbit/s)
- UPS also connected to the switch so Wi-Fi stays up during power outages

## Physical Location

All infrastructure lives behind the TV (spouse acceptance factor). UPS is on the left, 3 Beelinks stacked on the right.
