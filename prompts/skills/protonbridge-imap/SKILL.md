---
name: protonbridge-imap
description: 'Access ProtonMail mailboxes locally through Proton Bridge over IMAP (STARTTLS on 127.0.0.1 port 1143). Use when the user asks to read, list, search, count, or fetch emails from Proton Mail / ProtonMail / Proton Bridge, check inbox, list folders, or interact with the local IMAP bridge. Reads credentials from ~/.protonbridge. Triggers on: protonbridge, proton bridge, proton mail, protonmail, imap, list emails, read inbox.'
---

# Proton Bridge IMAP Access

This skill lets you read mail from the local Proton Bridge IMAP server.

## Credentials

Credentials live in `~/.protonbridge` (chmod 600) as `KEY=VALUE` pairs:

- `IMAP_HOST` (127.0.0.1)
- `IMAP_PORT` (1143)
- `IMAP_USER` (e.g. mail@paul.buetow.org)
- `IMAP_PASS` (bridge-generated password, NOT the Proton account password)
- `IMAP_SECURITY` (STARTTLS)

Bridge also exposes SMTP on 127.0.0.1:1025 with the same user/password.

Never echo `IMAP_PASS` to the terminal or commit it. Load it via shell:

```bash
set -a; . ~/.protonbridge; set +a
```

## Connecting

Bridge listens on plain TCP and upgrades via STARTTLS. The certificate is
self-signed by Bridge, so verification must be disabled.

Use Python's `imaplib` — it is preinstalled and handles STARTTLS cleanly:

```python
import imaplib, os, ssl
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE
M = imaplib.IMAP4(os.environ['IMAP_HOST'], int(os.environ['IMAP_PORT']))
M.starttls(ssl_context=ctx)
M.login(os.environ['IMAP_USER'], os.environ['IMAP_PASS'])
```

Do NOT use `imaplib.IMAP4_SSL` on port 1143 — Bridge requires STARTTLS, not
implicit TLS.

## Common operations

List folders:

```python
typ, folders = M.list()
for f in folders: print(f.decode())
```

Notable folders: `INBOX`, `Archive`, `Sent`, `Drafts`, `Spam`, `Trash`,
`All Mail`, `Starred`, and user folders under `Folders/...` (e.g.
`Folders/Newsletter`). Quote names with spaces: `M.select('"All Mail"')`.

List recent message headers in INBOX:

```python
M.select('INBOX')
_, data = M.search(None, 'ALL')
ids = data[0].split()
for num in ids[-20:]:
    _, msg = M.fetch(num, '(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])')
    print('---', num.decode())
    print(msg[0][1].decode(errors='replace').strip())
```

Use `BODY.PEEK[...]` instead of `BODY[...]` so messages stay unread.

Search examples (RFC 3501):

- Unread: `M.search(None, 'UNSEEN')`
- From sender: `M.search(None, 'FROM', '"alice@example.com"')`
- Since date: `M.search(None, 'SINCE', '01-May-2026')`
- Subject text: `M.search(None, 'SUBJECT', '"invoice"')`

Fetch a full message and decode subjects properly:

```python
import email
from email.header import decode_header
_, msg = M.fetch(num, '(BODY.PEEK[])')
m = email.message_from_bytes(msg[0][1])
subj = ''.join(
    s.decode(c or 'utf-8', errors='replace') if isinstance(s, bytes) else s
    for s, c in decode_header(m['Subject'] or '')
)
```

Always finish with `M.logout()`.

## One-shot shell helper

For quick "list latest N from a folder" tasks:

```bash
set -a; . ~/.protonbridge; set +a
python3 - <<'PY'
import imaplib, os, ssl, sys
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
M = imaplib.IMAP4(os.environ['IMAP_HOST'], int(os.environ['IMAP_PORT']))
M.starttls(ssl_context=ctx)
M.login(os.environ['IMAP_USER'], os.environ['IMAP_PASS'])
M.select('INBOX')
_, data = M.search(None, 'ALL')
for num in data[0].split()[-10:]:
    _, msg = M.fetch(num, '(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])')
    print('---', num.decode()); print(msg[0][1].decode(errors='replace').strip())
M.logout()
PY
```

## Troubleshooting

- `Connection refused` → Proton Bridge is not running. Start the Bridge app.
- `LOGIN failed` → password rotated in Bridge; regenerate and update
  `~/.protonbridge`.
- `socket.gaierror` → don't use `localhost` if IPv6 is broken; stick to
  `127.0.0.1`.
- `STARTTLS extension not supported` → you connected with `IMAP4_SSL`; use
  plain `IMAP4` then `starttls()`.
