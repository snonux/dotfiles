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

The relayd fix pattern (see `frontends/etc/relayd.conf.tpl`): `block request
header "Host" value "<host>"` inside the `"https"` protocol. Notes:

- **`block quick` is not valid relayd syntax here** — it fails
  `relayd -n`. Plain `block` is correct.
- Always `relayd -n` before deploying, and deploy **one gateway at a time**
  (a relayd restart briefly drops every public site on that gateway).
- Leave port 80 alone — it never proxies to the cluster (httpd handles
  ACME/redirect), and blocking it breaks certificate renewal.
- Keep a non-standard port alive if humans still need the UI (Forgejo kept
  one); skip that for a service nobody browses.

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
