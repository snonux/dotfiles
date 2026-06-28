# End-to-end IMAP scan one-shot script

This script implements steps 1-3 of the workflow (scan all Shopping folders,
classify, extract tracking codes/carriers) in a single pass. It is read-only
(`BODY.PEEK`, `readonly=True`) and idempotent.

## Prerequisites (from the `protonbridge-imap` skill)

The IMAP connection is **not** re-derived here. Load credentials and connect as
shown in the [`protonbridge-imap` skill](../protonbridge-imap/SKILL.md): load
`~/.protonbridge` into the environment, then `imaplib.IMAP4` → `starttls`
(self-signed cert, so `ssl.CERT_NONE`) → `login`, yielding a logged-in
connection `M`. The `decode_header`-based subject decode pattern shown there is
reused below via a small local `dh()` wrapper.

This one-shot assumes `M` is already a logged-in IMAP4 connection. Only the
shopping-specific scanning/classification/extraction logic below is unique to
this skill.

## Shopping scan

`dh()` is a small local def that wraps `decode_header` (shown in
`protonbridge-imap`); kept inline because it runs on every subject/sender.

```bash
set -a; . ~/.protonbridge; . ~/.amazon; set +a
python3 - <<'PY'
import imaplib, os, ssl, email, re, html
from email.header import decode_header

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
5. Run the CDP login + navigate + extract sequence from
   [amazon-cdp.md](amazon-cdp.md).
6. Parse the returned `innerText` for delivery status, tracking ID, and ETA.

After this prints the candidates, run the headless-Chrome lookup loop for
each tracking code/URL and assemble the final markdown report following the
format in step 5 of the parent `SKILL.md`.