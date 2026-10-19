# Network troubleshooting: worked case and traps

## Worked Case: the Crawler That Moved (2026-08-19/20)

1. A crawler walked Forgejo's expensive blame/commit/diff pages, ~3-7.5 Mbps
   sustained. Blocked `code.f3s.buetow.org` at relayd.
2. **Traffic continued.** Blocking one hostname does not stop a bot that can
   find another door — it had moved to `c-git.f3s.buetow.org`, the legacy
   cgit UI, which renders equally expensive per-commit pages.
3. Only enabling Traefik metrics made this visible; per-pod counters were too
   coarse. Lesson: **verify the traffic actually stopped**, don't assume the
   block worked.

The relayd fix pattern (see `gonf/frontends/assets/relayd.conf.tmpl`): `block request
header "Host" value "<host>"` inside the `"https"` protocol. Notes:

- **`block quick` is not valid relayd syntax here** — it fails
  `relayd -n`. Plain `block` is correct.
- Always `relayd -n` before deploying, and deploy **one gateway at a time**
  (a relayd restart briefly drops every public site on that gateway).
- Leave port 80 alone — it never proxies to the cluster (httpd handles
  ACME/redirect), and blocking it breaks certificate renewal.
- Keep a non-standard port alive if humans still need the UI (Forgejo kept
  one); skip that for a service nobody browses.

## Worked Case: Recursive Directory Crawler (2026-10-19)

Mischa reported fishfinger (OpenBSD Amsterdam vm24 on server11) above 80%
CPU for six hours. Live samples showed 95–98% CPU busy on its single vCPU,
load around 4, and three `relayd: ca` processes using about 25% CPU each.
An external client, `185.177.72.38` with user-agent `curl/8.7.1`, was hitting
**both** fishfinger and blowfish over HTTPS. It accounted for 18,716 of
about 20,000 recent fishfinger access-log requests (~16 requests/second).

Requests looked like `/?p=info/gogios/foostats/foostats/gogios/...`.
The frontend FQDNs serve `/var/www/htdocs/buetow.org/self` with httpd
`directory auto index`. `/`, `/?p=info/`, and the growing query strings all
returned the identical 2,504-byte listing, containing relative `gogios/`
and `foostats/` links. This is consistent with a crawler incorrectly
appending links to the query string; its implementation/operator is unknown.

The names did **not** establish Gogios as the source. Both hosts' cron jobs,
daily hooks and live Gogios configs were checked: Gogios uses `check_http`
against fixed URLs every five minutes; Foostats replicates dated files with
Perl LWP. Neither crawls links. `pfctl -ss` confirmed actual incoming TCP
connections from the external IP, independently of forwarded HTTP headers.

The persistent mitigation is in conf's `frontends/etc/pf.conf.tpl`, after
the general `pass` rule and before the accounting passes:

```pf
block drop in quick on vio0 from 185.177.72.38 label "abusive_crawler"
```

`quick` matters: later labelled `pass` rules would otherwise override the
block. Deploy with `./gonf.sh cluster frontends frontends_pf`, which
validates using `pfctl -n` before replacement and reload. Then remove only
the offending source's existing states on **each** host:

```sh
doas pfctl -k 185.177.72.38
```

The initial deployment removed 1,646 states on fishfinger and 2,362 on
blowfish. CPU usage dropped immediately on both without restarting relayd.
After two minutes, fishfinger's final interval samples were 6–9% CPU busy
(briefly higher during scheduled checks), with one-minute load down from
4.25 to 0.97; blowfish was about 1–2% busy, with load down from 0.47 to
0.08. Both had zero source states; the rule had dropped 406 and 252 packets,
respectively. Public HTTPS health checks and both daemons remained healthy.
For a recurrence, use `relayctl show sessions` / `show relays`,
`/var/www/logs/access.log`, and `/var/log/daemon` to identify the current
source; do not assume it is still this IP. Observe interval samples with
`vmstat -w 10 -c 13` (ignore the first, since-boot row), check load averages
as they decay, confirm zero source states, and inspect
`pfctl -sl | grep abusive_crawler` for blocked traffic.

## Trap: Flaky Registry + `imagePullPolicy: Always`

A slow/flaky **external registry** turns into sustained internal load when a
manifest sets `imagePullPolicy: Always` on a **pinned version tag**: every
pod (re)start forces a live registry check even though the image is already
cached on every node. If that check fails, the pod backs off and retries —
forever. At k3s restart all ~30 apps resync at once and it becomes a storm.

cert-manager sat in `ErrImagePull`/`CrashLoopBackOff` for 9-10 days this way
against `quay.io` (measured failing ~1-in-5 requests from this network).
Fix: `IfNotPresent` for pinned tags.

Check whether the image is *already* cached before believing a pull error:

```sh
crictl images | grep <image>
kubectl get pods -A | grep -E 'ImagePullBackOff|ErrImagePull|CrashLoopBackOff'
```

Do **not** blanket-apply `IfNotPresent`: for `:latest` tags it silently
freezes updates, and for local-registry images re-pushed under the same tag
(`registry.lan.buetow.org:30001/...`) `Always` is load-bearing.

## IPv4 vs IPv6

Test address families separately — a fault in one is invisible if `curl`
picks the other. Observed here: several destinations (`quay.io`,
`www.google.com`) resolve **IPv6-only** from this network, so a v6-specific
problem looks like "that site is down" while everything else works.

Measured 2026-08-20: IPv4 was consistently the *healthier* path; IPv6 to
Google was mildly flaky (5s SYN-retransmit stalls, occasional timeouts) while
IPv6 to heise.de was 20/20 perfect — i.e. destination-specific, not a broken
local v6 stack. Don't generalise from one destination.

## NFS Is Usually Not It

NFS rides `stunnel` to the LAN CARP VIP over `127.0.0.1`/LAN and **never
touches `wg0`**, so it cannot cause a WAN-side slowdown regardless of volume.
Rule it out in seconds — zero `retrans` means healthy:

```sh
nfsstat -c   # on each r-node; check the retrans column
```

See [Storage](../storage.md) for genuine NFS faults.

## Don't Trust Stale Notes

`f3s/references/hardware.md` claimed a TP-Link EAP615-Wall as the switch;
the gateway at `192.168.1.1` actually serves **`thttpd`** (not OpenWrt's
`uhttpd`), so that topology was wrong and an "AP is the bottleneck"
hypothesis built on it had to be dropped. Fingerprint the live network before
theorising:

```sh
curl -s -I --max-time 5 "http://$gw/" | head
arp -an
ifconfig re0 | grep -E 'media|status'   # confirm negotiated link speed
```
