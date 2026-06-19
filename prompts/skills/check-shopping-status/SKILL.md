---
name: check-shopping-status
description: 'Audit the Proton Mail Shopping folders, find every shipment/order email, extract tracking numbers and carriers, and report current delivery status. Use when the user asks where their packages are, to check shopping status, the status of orders/parcels/deliveries, any updates on shipments, or wants a consolidated overview of recent purchases. Combines the protonbridge-imap skill (mailbox access) with headless-Chrome scraping for carrier tracking. Triggers on: shopping status, package status, delivery status, where is my package, check my shipments, parcel update, tracking status.'
---

# Check Shopping Status

End-to-end workflow that turns "what's the status of my deliveries?" into a
single report.

Prerequisites:

- [`protonbridge-imap`](../protonbridge-imap/SKILL.md) skill loaded for
  IMAP access; credentials live in `~/.protonbridge`.
- Amazon credentials in `~/.amazon` as `user:...` and `pass:...` lines.
- `google-chrome` (or `chromium`) available for JS-rendered carrier pages.
- `python3` with stdlib (`imaplib`, `email`, `ssl`, `json`, `urllib.request`).
- `websocat` for headless-Chrome remote-debugging WebSocket protocol.

## Reference Files

Detailed runnable code is in the `references/` subfolder:

- [IMAP scan one-shot script](references/imap-scan-script.md) — the full
  read-only Python script implementing steps 1-3 (scan Shopping folders,
  classify, extract codes/carriers) plus the post-extraction Amazon loop.
- [Amazon CDP lookup](references/amazon-cdp.md) — headless-Chrome / Chrome
  DevTools Protocol login + navigate + extract sequence and the reusable
  Python helper (`start_chrome`, `get_page_ws`, `send_cmd`,
  `amazon_login_and_track`).

## Workflow

### 1. Scan all Shopping folders

Recurse `Folders/Shopping` and its subfolders (typically
`Folders/Shopping/Backing` and `Folders/Shopping/BackingButAddressIssues`).
For each message capture: id, From, Subject, Date, plain-text + decoded HTML
body.

Folder names with spaces must be wrapped in double-quotes when selecting:
`M.select('"Folders/Shopping"', readonly=True)`. Always use `BODY.PEEK[...]`
so the seen flag is not changed.

### 2. Classify each mail

Use these signal categories (in order):

| Category | How to detect |
|---|---|
| **Shipment with tracking** | Subject/body contains "shipped", "versandt", "on its way", "ausgeliefert", "Sendungsnummer", "tracking number" *and* a tracking code OR a recognisable carrier tracking URL. |
| **Order confirmation only** | "Order confirmation", "Bestellbestätigung", "Vielen Dank für Ihre Bestellung" without a tracking code. |
| **Payment / admin** | PayPal, PayU, Klarna, donation receipts. |
| **Pledge / pre-ship** | Kickstarter "You just backed…", "Pledge collected", project updates. |
| **Address / response needed** | "Response needed", "address issue", survey reminders. |
| **Marketing** | Newsletters from Proton/Amazon/PledgeBox with no real shipment context. |

Mark only the first category as ✅ trackable; everything else as
informational. Filter out false positives: marketing mails often contain the
word "tracking" only in UTM links (`utm_source=tracking_email`).

### 3. Extract tracking codes and carriers

Carrier regexes (apply against the decoded body, dedupe matches):

| Carrier | Pattern |
|---|---|
| DHL international piece | `\b[A-Z]{2}\d{9}DE\b` |
| DHL domestic | `\bJJD\d{12,20}\b` or `\b\d{12,14}\b` (filter `0+`) |
| UPS | `\b1Z[0-9A-Z]{16}\b` |
| USPS / S10 | `\b9\d{15,21}\b` or `\b[A-Z]{2}\d{9}US\b` |
| Asendia / Pirate Ship | `\bAHOY\w+\b` |
| Royal Mail | `\b[A-Z]{2}\d{9}GB\b` |
| FedEx | `\b\d{12}\b` or `\b\d{15}\b` |
| Generic numeric | `\b\d{10,30}\b` (only when carrier domain matches) |

Also pull every `https://...track...|sendung|paket|versand|swiship|asendia|
17track|temu...` URL — it often contains the most reliable id (Amazon
`shipmentId=`, Temu `track_sn=`, Swiship `?id=`).

Reject placeholder garbage: `6666666666...`, `3333333333...`, `0000000000`.

The runnable Python implementation of steps 1-3 lives in
[references/imap-scan-script.md](references/imap-scan-script.md).

### 4. Look up status per carrier

Run lookups in parallel where possible. Quick reference for what works
without API keys:

| Carrier | Reachable? | How |
|---|---|---|
| **Swiship / FAN Courier** (`swiship.co.uk/track?loc=de-DE&id=...`) | ✅ headless Chrome (`virtual-time-budget=20000`) | Plain text already in DOM. |
| **Asendia USA** (`a1.asendiausa.com/tracking/?trackingnumber=...&trackingkey=...`) | ✅ direct curl | First page render contains last event. |
| **Amazon DE/COM** (`progress-tracker?orderId=...&shipmentId=...`) | ✅ via headless Chrome with `~/.amazon` creds | Log in via CDP, navigate to progress-tracker URL, extract `document.body.innerText`. See [references/amazon-cdp.md](references/amazon-cdp.md). |
| **Temu** (`api-euo.temu.com/callback/doha/open/track?...`) | ❌ needs Temu account | Use the rendered mail text instead ("Order shipped", "transferred to Bulgarian Post"). |
| **DHL** (`nolp.dhl.de`, `dhl.de/int-verfolgen`, `dhl.com/utapi`) | ❌ blocked | Akamai bot challenge + explicit HTTP 403 *"tracking attempt has been blocked"*. Aggregators (17track, parcelsapp, AfterShip, parcelmonitor) also fail without paid API keys. Fall back to the email body for context (sender hand-off date, delivery partner, expected days) and link the user to `https://nolp.dhl.de/nextt-online-public/set_identcodes.do?lang=en&idc=<CODE>`. |
| **Bulgarian Post / Speedy** | ❌ Cloudflare challenge | Same fallback — quote what the mail says. |
| **Kickstarter / PledgeBox** | n/a | These don't carry carrier codes; status comes from the project update text. |

For Amazon.de/.com tracking URLs that require login, follow the
Chrome-DevTools-Protocol sequence and helper in
[references/amazon-cdp.md](references/amazon-cdp.md).

### 5. Produce the report

Always group by folder. Inside each folder produce a table with these
columns: # · Item · Carrier/Code · Status. Use these status badges so the
user can scan visually:

- ✅ Delivered / clear good outcome
- 🚚 In transit (with date or ETA when known)
- 🟡 Handed to local carrier / pending pickup
- 🟠 Label created, not yet inducted
- ⏳ Pre-ship / awaiting production
- 🔒 Lookup needs login
- ❓ Carrier blocked automated lookup — manual check link
- 📋 Action needed from user (address, survey)

End the report with a short "Things worth acting on" list: imminent
deliveries, address issues to answer, codes that haven't moved.

## Tips

- Re-running is cheap and idempotent — IMAP is read-only and Chrome writes
  to `/tmp/track/`. Wipe `/tmp/track/` between runs to avoid stale state.
- Cache the user's recent report under `~/.cache/check-shopping-status/`
  (date-stamped JSON) so the next run can diff "what's new since last
  time".
- When in doubt about a code being a real tracking number, link to the
  carrier's tracking page so the user can verify in their own browser
  (where they're logged in / not blocked).
- Never spam the same carrier endpoint with retries when it returns a bot
  challenge — Akamai's `_abck` and Cloudflare's challenge cookies get
  worse with each attempt.
