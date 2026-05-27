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

### 4. Look up status per carrier

Run lookups in parallel where possible. Quick reference for what works
without API keys:

| Carrier | Reachable? | How |
|---|---|---|
| **Swiship / FAN Courier** (`swiship.co.uk/track?loc=de-DE&id=...`) | ✅ headless Chrome (`virtual-time-budget=20000`) | Plain text already in DOM. |
| **Asendia USA** (`a1.asendiausa.com/tracking/?trackingnumber=...&trackingkey=...`) | ✅ direct curl | First page render contains last event. |
| **Amazon DE/COM** (`progress-tracker?orderId=...&shipmentId=...`) | ✅ via headless Chrome with `~/.amazon` creds | Log in via CDP, navigate to progress-tracker URL, extract `document.body.innerText`. |
| **Temu** (`api-euo.temu.com/callback/doha/open/track?...`) | ❌ needs Temu account | Use the rendered mail text instead ("Order shipped", "transferred to Bulgarian Post"). |
| **DHL** (`nolp.dhl.de`, `dhl.de/int-verfolgen`, `dhl.com/utapi`) | ❌ blocked | Akamai bot challenge + explicit HTTP 403 *"tracking attempt has been blocked"*. Aggregators (17track, parcelsapp, AfterShip, parcelmonitor) also fail without paid API keys. Fall back to the email body for context (sender hand-off date, delivery partner, expected days) and link the user to `https://nolp.dhl.de/nextt-online-public/set_identcodes.do?lang=en&idc=<CODE>`. |
| **Bulgarian Post / Speedy** | ❌ Cloudflare challenge | Same fallback — quote what the mail says. |
| **Kickstarter / PledgeBox** | n/a | These don't carry carrier codes; status comes from the project update text. |

### 4b — Amazon lookup via Chrome DevTools Protocol

For Amazon.de (or .com) tracking URLs that require login, use a headless
Chrome instance controlled via the remote-debugging WebSocket protocol.

```bash
# Start Chrome with remote debugging
pkill -f 'remote-debugging-port=9222' || true
google-chrome \
  --headless=new --disable-gpu --no-sandbox --disable-dev-shm-usage \
  --disable-blink-features=AutomationControlled \
  --window-size=1400,2400 \
  --user-agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36' \
  --remote-debugging-port=9222 --user-data-dir=/tmp/amazon-profile \
  about:blank
```

Create a tab via `PUT http://localhost:9222/json/new?about:blank`, connect
with `websocat <wsUrl>`, then send CDP commands in line-delimited JSON:

1. `Page.enable` — subscribe to page events.
2. `Page.navigate` — load `https://www.amazon.de/ap/signin`.
3. `Runtime.evaluate` — set `#ap_email` to `~/.amazon` user and click `#continue`.
4. `Runtime.evaluate` — set `#ap_password` to `~/.amazon` pass and click `#signInSubmit`.
5. `Page.navigate` — load the progress-tracker URL from the email.
6. `Runtime.evaluate` — return `document.body.innerText` for status extraction.

Important interaction details:
- Dispatch `input` and `change` events on form fields after setting `.value`.
- Click the submit button, then call `form.submit()` as fallback.
- Amazon sign-in often redirects to `openid` flow; the final URL after step
  5 should match the original progress-tracker URL.

Then strip tags and grep for status keywords:
`deliver|delivered|in transit|out for delivery|zugestellt|unterwegs|abgeholt|
expected|arrived|departed|customs`.

If the screenshot is < 60 KB or contains the words "Cloudflare", "security
verification", "Bot Manager", "Pardon Our Interruption", or "blocked" →
mark the lookup as **blocked**, do *not* keep retrying with the same client.

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

### Example Amazon CDP helper

```python
import json, subprocess, time, urllib.request

def start_chrome():
    subprocess.run(['pkill','-f','remote-debugging-port=9222'], capture_output=True)
    time.sleep(1)
    p = subprocess.Popen([
        'google-chrome',
        '--headless=new','--disable-gpu','--no-sandbox','--disable-dev-shm-usage',
        '--disable-blink-features=AutomationControlled',
        '--window-size=1400,2400',
        '--user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        '--remote-debugging-port=9222','--user-data-dir=/tmp/amazon-profile',
        'about:blank'
    ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    for _ in range(30):
        time.sleep(0.5)
        try:
            with urllib.request.urlopen('http://localhost:9222/json/version', timeout=2) as r:
                if json.loads(r.read()).get('Browser'):
                    return p
        except: pass
    p.kill()
    raise RuntimeError('Chrome did not start')

def get_page_ws():
    req = urllib.request.Request('http://localhost:9222/json/new?about:blank', method='PUT')
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read()).get('webSocketDebuggerUrl','')

def send_cmd(ws, cid, method, params=None):
    ws.stdin.write((json.dumps({'id':cid,'method':method,'params':params or {}},ensure_ascii=False)+'\n').encode())
    ws.stdin.flush()

def amazon_login_and_track(ws, user, pwd, tracker_url):
    send_cmd(ws, 1, 'Page.enable')
    send_cmd(ws, 2, 'Runtime.evaluate', {'expression': 'navigator.webdriver'})
    time.sleep(0.5)
    send_cmd(ws, 3, 'Page.navigate', {'url':'https://www.amazon.de/ap/signin'})
    time.sleep(7)
    send_cmd(ws, 4, 'Runtime.evaluate', {
        'expression': f"""
            var e=document.querySelector('#ap_email');
            var c=document.querySelector('#continue');
            if(e){{ e.focus(); e.value='{user}'; e.dispatchEvent(new Event('input',{{bubbles:true}})); e.dispatchEvent(new Event('change',{{bubbles:true}})); }}
            if(c){{ c.focus(); c.click(); }}
            JSON.stringify({{found:!!e}});
        """, 'returnByValue': True
    })
    time.sleep(7)
    send_cmd(ws, 5, 'Runtime.evaluate', {
        'expression': f"""
            var p=document.querySelector('#ap_password');
            var b=document.querySelector('#signInSubmit');
            if(p){{ p.focus(); p.value='{pwd}'; p.dispatchEvent(new Event('input',{{bubbles:true}})); }}
            if(b){{ b.focus(); b.click(); var f=p?p.closest('form'):null; if(f)f.submit(); }}
            JSON.stringify({{found:!!p}});
        """, 'returnByValue': True
    })
    time.sleep(9)
    send_cmd(ws, 6, 'Runtime.evaluate', {'expression':'location.href','returnByValue':True})
    time.sleep(1)
    send_cmd(ws, 7, 'Page.navigate', {'url': tracker_url})
    time.sleep(7)
    send_cmd(ws, 8, 'Runtime.evaluate', {'expression':'document.body.innerText','returnByValue':True})
    time.sleep(1)
    ws.stdin.close()
    out=[]; err=[]
    while True:
        line=ws.stdout.readline()
        if not line: break
        try: out.append(json.loads(line.decode()))
        except: pass
    while True:
        line=ws.stderr.readline()
        if not line: break
        err.append(line.decode())
    ws.wait()
    return out
```

## End-to-end one-shot script

```bash
set -a; . ~/.protonbridge; . ~/.amazon; set +a
python3 - <<'PY'
import imaplib, os, ssl, email, re, html
from email.header import decode_header

ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
M = imaplib.IMAP4(os.environ['IMAP_HOST'], int(os.environ['IMAP_PORT']))
M.starttls(ssl_context=ctx); M.login(os.environ['IMAP_USER'], os.environ['IMAP_PASS'])

def dh(s):
    if not s: return ''
    return ''.join(p.decode(c or 'utf-8','replace') if isinstance(p, bytes) else p
                   for p,c in decode_header(s))

CARRIERS = {
    'DHL-INT':   re.compile(r'\b[A-Z]{2}\d{9}DE\b'),
    'DHL':       re.compile(r'\bJJD\d{12,20}\b'),
    'UPS':       re.compile(r'\b1Z[0-9A-Z]{16}\b'),
    'USPS':      re.compile(r'\b9\d{15,21}\b'),
    'Asendia':   re.compile(r'\bAHOY\w+\b'),
    'RoyalMail': re.compile(r'\b[A-Z]{2}\d{9}GB\b'),
}
SHIP_KW = re.compile(r'(track(ing)?[\s_-]*(number|code|id|link)?|sendungsnummer|sendungsverfolgung|shipped|versandt|on its way|delivered|geliefert|out for delivery|ausgeliefert|unterwegs)', re.I)
URL_RE  = re.compile(r'https?://[^\s<>"\']+')
JUNK    = {'00000000000000','0000000000','66666666666667','333333333333336'}

def body_text(m):
    parts=[]
    if m.is_multipart():
        for p in m.walk():
            if p.get_content_type() in ('text/plain','text/html'):
                try: parts.append(p.get_payload(decode=True).decode(p.get_content_charset() or 'utf-8','replace'))
                except: pass
    else:
        try: parts.append(m.get_payload(decode=True).decode(errors='replace'))
        except: pass
    return '\n'.join(parts)

for folder_q in ['"Folders/Shopping"', '"Folders/Shopping/Backing"', '"Folders/Shopping/BackingButAddressIssues"']:
    typ,_ = M.select(folder_q, readonly=True)
    if typ!='OK': continue
    _, data = M.search(None, 'ALL')
    ids = data[0].split()
    print(f'\n=== {folder_q} ({len(ids)} messages) ===')
    for num in ids:
        _, msg = M.fetch(num, '(BODY.PEEK[])')
        m = email.message_from_bytes(msg[0][1])
        subj = dh(m.get('Subject','')); frm=dh(m.get('From','')); date=m.get('Date','')
        body = body_text(m)
        codes=[]
        for name,pat in CARRIERS.items():
            for c in set(pat.findall(body)):
                if isinstance(c,tuple): c=c[0]
                if c not in JUNK: codes.append(f'{name}:{c}')
        urls = [u for u in URL_RE.findall(body) if re.search(r'track|sendung|paket|versand|swiship|asendia|temu|amazon.*progress-tracker', u, re.I)]
        ship = bool(SHIP_KW.search(subj+'\n'+body)) or codes or urls
        flag = '📦' if ship else '  '
        print(f'{flag} #{num.decode():>3} {date[:25]:25s} {frm[:38]:38s} {subj[:80]}')
        for c in codes[:3]: print(f'      code: {c}')
        for u in urls[:2]:  print(f'      url:  {u[:160]}')
M.logout()
PY
```

After IMAP extraction, for every Amazon progress-tracker URL:
1. Load `~/.amazon` credentials.
2. Spin up headless Chrome with `--remote-debugging-port=9222`.
3. Create a new tab via `PUT http://localhost:9222/json/new?about:blank`.
4. Connect `websocat` to the returned `webSocketDebuggerUrl`.
5. Run the CDP login + navigate + extract sequence shown above.
6. Parse the returned `innerText` for delivery status, tracking ID, and ETA.

After this prints the candidates, run the headless-Chrome lookup loop for
each tracking code/URL and assemble the final markdown report following the
format in step 5.

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
