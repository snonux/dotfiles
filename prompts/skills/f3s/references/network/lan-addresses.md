# LAN IPv4 address inventory

Network: **192.168.1.0/24**. All abbreviated addresses below use `192.168.1.`.
Evidence collected on **2026-10-25**, including an ARP scan at approximately
14:44 UTC, local `/etc/hosts`, the f3s inventory, OpenWrt UCI and lease records,
and DHCP discovery after the pool change at approximately 14:46 UTC.

## DHCP pools and reservations

| Server | Pool | Evidence / status |
|---|---|---|
| OpenWrt AP `.101` | `.200–.239` | Applied and verified: UCI start `200`, limit `40`; dnsmasq running; live offer `.209` |
| Vivacom gateway `.1` | `.240–.254` | User's intended final range; `.240–.250` previously reported configured, then upper bound extended by user to `.254`. Live offer `.240` verified; upper boundary not independently read from router |

Both servers hand out gateway `.1`. Vivacom advertises DNS `.1` with a 24-hour
lease; OpenWrt advertises DNS `.101`, domain `lan.buetow.org`, and a one-hour
lease. Their pools do not overlap, but clients can obtain different DNS
settings depending on which server supplies the lease.

OpenWrt retains a reservation for **earth at `.113`**, matching hardware MAC
`10:3D:1C:C8:39:3F`. During inspection earth used randomized MAC
`2A:DE:CF:45:66:A0` and held an existing Vivacom lease at `.6` instead.
Do not assume the reservation matches every connection from earth.

OpenWrt previously served `.150–.199`. Existing leases from that pool remained
in its lease file immediately after the change; clients may retain old addresses
until renewal or reconnection. Do not treat the old pool as immediately free.
Vivacom clients may likewise retain old low-numbered leases.

`.0` is the network address and `.255` is the broadcast address. `.254` is a
valid host address and belongs to the intended Vivacom pool.

## Fixed inventory and local name mappings

The [main skill inventory](../../SKILL.md#quick-reference-host-ips) is the
canonical table for routers, f0–f3, r0–r2, rocky, pi0–pi3, the `.138` CARP VIP,
zen, the Shelly plugs and freebsd/fbsd. It includes these LAN addresses:

- Routers: `.1`, `.101`.
- Hosts-file additions: `.13` zen, `.28` shelly1, `.29` shelly2,
  `.139` freebsd/fbsd.
- f3s infrastructure: `.120–.123`, `.125–.128`, `.130–.133`, `.138`.

All answered the scan except **zen `.13`** and **freebsd `.139`**.
Keep their documented addresses set aside despite the lack of a response.
Hosts-file entries prove name mappings, not the device's allocation method.
The commented `.10 foo.example.org` and `.13 bar.example.org` examples in
`/etc/hosts` are not inventory entries. WireGuard `192.168.2.x` and
`192.168.3.x` entries are outside this LAN.

## Other active addresses and DHCP leases

The scan found **30 responding addresses**, including the responding fixed
inventory above and the clients below. These are observations, not permanent
assignments; rescan and reread leases before relying on them.

| Address | Identity | Evidence at inspection |
|---|---|---|
| `.6` | earth | Active; NetworkManager confirms Vivacom DHCP lease |
| `.11` | Unknown | Active; allocation unconfirmed |
| `.12` | Unknown | Active; allocation unconfirmed |
| `.14` | Unknown | Active; allocation unconfirmed |
| `.15` | Unknown | Active; allocation unconfirmed |
| `.16` | Unknown | Active; allocation unconfirmed |
| `.18` | Unknown | Active; allocation unconfirmed |
| `.30` | Unknown | Active; MAC `20:28:BC:72:0D:4E` |
| `.151` | Unnamed client | Active; OpenWrt lease; MAC `30:52:53:03:57:38` |
| `.158` | jetkvm-e10a0883debf7d4a | Active; OpenWrt lease; MAC `30:52:53:08:97:97` |
| `.164` | Unnamed client | OpenWrt lease, no scan response; MAC `1E:F3:75:69:30:5F` |
| `.191` | jetkvm-f72978d7f87aa969 | Active; OpenWrt lease; MAC `30:52:53:06:8B:21` |
| `.198` | jetkvm-cee6ab4df2f88754 | Active; OpenWrt lease; MAC `30:52:53:04:A4:4B` |
| `.199` | Mac | Active; OpenWrt lease; MAC `7A:3F:D8:AB:A2:A9` |

OpenWrt's earlier ARP cache also held **stale** entries for `.3`, `.5`, `.7`,
`.9`, `.19`, `.21`, and `.173`. Those did not answer the scan and are evidence
of previous use only. Do not confuse FAILED neighbor entries with occupied
addresses.

Discovery probes received offers for `.8` (Vivacom) and `.150` (OpenWrt)
before the changes, then `.240` (Vivacom) and `.209` (OpenWrt) afterward.
Offers alone are not confirmed client allocations.

No `.240–.254` address answered the 14:44 UTC scan. Absence from a scan does
not establish availability: sleeping clients, reservations and outstanding
leases must also be considered. Do not assign static addresses inside either
DHCP pool.
