# Follow-up Mail

Send only when Paul asks for that specific mail. Report the exact text that
went out.

## Before writing

1. Check `Sent` for what Paul already asked and when, and read the seller's
   last answer. The follow-up should quote the seller's own date back to them.
2. Reply in the existing thread rather than starting a new one, so the seller
   sees the order and the earlier promise.

## Addressing

- **From:** the address Paul used earlier in that thread. Bridge accepts any
  address of the account, whichever address logs in.
- **To:** the seller's `Reply-To` from their last message, not the no-reply
  order address.
- **Subject:** `Re: <original subject>`.
- **In-Reply-To:** the `Message-Id` of the last message in the thread.
- **References:** the previous message's `References` plus its `Message-Id`.
  Drop the `…@protonmail.internalid` entries; they are Proton-internal.

Read those headers with:

```
BODY.PEEK[HEADER.FIELDS (FROM TO REPLY-TO SUBJECT DATE MESSAGE-ID REFERENCES IN-REPLY-TO)]
```

## Wording

Short and plain, matching Paul's own mails: greeting, order number and item,
order date, what the seller promised, what has not arrived, one question, sign
off "Thanks and regards, Paul". No signature block.

## Sending

Bridge SMTP is `127.0.0.1:1025` with STARTTLS and the same login as IMAP (see
[`protonbridge-imap`](../../protonbridge-imap/SKILL.md); use the password file
named in [mail-search.md](mail-search.md)). The certificate is self-signed.

```python
import os, smtplib, ssl
from email.message import EmailMessage
from email.utils import formatdate, make_msgid

msg = EmailMessage()
msg["From"] = thread_from   # the address Paul used earlier in this thread
msg["To"] = "Seller <hello@example.com>"
msg["Subject"] = "Re: Order Confirmation #12345"
msg["Date"] = formatdate(localtime=False)
msg["Message-ID"] = make_msgid(domain="protonmail.com")
msg["In-Reply-To"] = last_message_id
msg["References"] = " ".join(thread_ids + [last_message_id])
msg.set_content(body)

ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
pw = open(os.path.expanduser("~/.config/aerc/protonbridge-password")).read().strip()
with smtplib.SMTP("127.0.0.1", 1025, timeout=60) as s:
    s.starttls(context=ctx)
    s.login("mail@paul.buetow.org", pw)
    refused = s.send_message(msg)   # {} means every recipient was accepted
```

## Verify

Bridge files the copy in `Sent` itself. Confirm it before saying the mail was
sent:

```bash
python3 scripts/imap_search.py --folder Sent --since <today> --to <seller domain>
```

Then record the follow-up and its date in `~/Notes/OrderStatus.md`.
