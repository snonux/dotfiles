# Mail Search

Connection details, credentials and the basic `imaplib` recipe are owned by
[`protonbridge` IMAP](../../protonbridge/references/imap.md). The tunnel, the pod
and the password file are owned by
[`protonbridge` aerc](../../protonbridge/references/aerc.md). This file covers only
what is specific to finding order mail.

## Password file

The Bridge password has one home, `~/.config/aerc/protonbridge-password`.
`scripts/imap_search.py` reads that file, and `~/.protonbridge` derives its
password from it. If login fails with `no such user`, follow the
troubleshooting in the `protonbridge` skill's IMAP and aerc references (the same error
also appears for a few minutes after the Bridge pod restarts, while it syncs).

## Folders

| Folder | What is there |
|---|---|
| `Folders/Kickstarter` | Order confirmations, project updates Paul filed, seller threads |
| `Archive` | Shipping and "order confirmed" mails, support threads, most pledge notices |
| `INBOX` | Recent project updates not yet filed |
| `Sent` | Paul's own questions to sellers (shows what was already asked) |
| `Trash` | Deleted project updates; still searchable and often the newest ones |
| `Folders/Shopping/Backing`, `…/BackingButAddressIssues`, `…/Backing/ProbablyReveived` | Paul's own triage folders; mostly empty, check anyway |

Mail that would carry a backer number (`You just backed …`, `We've collected
your pledge for …`) is often not kept. If it is missing, get the number from
Kickstarter instead of searching further.

## Senders and subjects

| Kind of mail | Search for |
|---|---|
| Kickstarter | `FROM kickstarter`; subjects `Project Update #N: <project>`, `You just backed`, `We've collected your pledge`, `Response needed: Get your reward`, `New message about` |
| Shop order confirmation | `SUBJECT "Order Confirmation"`, `SUBJECT "confirmed"`, `SUBJECT "pre-order"` |
| Shop shipping notice | `SUBJECT "shipment"`, `SUBJECT "on the way"`, `SUBJECT "shipped"`, `SUBJECT "tracking"` |
| Carrier notices | `FROM` the carrier (parcel services send their own delivery mails) |
| Third-party survey senders | Named in the creator's updates; their marketing mail lands in Trash, the survey itself may never arrive |

The sender domains and exact subjects of the sellers Paul actually uses are in
`~/Notes/OrderVendors.md` (see [private-notes.md](private-notes.md)); search
for those first.

A pledge-collected mail contains the line `Backer <n>` in its body.

## Bridge search pitfalls

- A long series of `SEARCH` commands on `All Mail`
  drops the connection (`socket error: EOF`) or runs past any reasonable
  timeout. Single searches on `All Mail` do work.
- Search the individual folders instead, and open a **new connection per
  folder** so one failure does not lose the rest.
- A large folder such as `Archive` takes several minutes for 30 searches. Keep
  the term list short and add `SINCE` to bound it.
- Run long searches in the background and print with `flush=True`, so partial
  results survive a timeout.
- Always `select(..., readonly=True)` and fetch with `BODY.PEEK[...]`.

## Using the script

```bash
# header lines for every hit, newest last
python3 scripts/imap_search.py --folder Archive --folder INBOX \
    --since 01-Apr-2026 --from kickstarter --subject "Project Update"

# print the bodies of specific messages in a folder
python3 scripts/imap_search.py --folder Archive --read 101 102 --limit 1500
```

Terms are OR-ed: a message is listed once if any `--from`, `--to` or
`--subject` term matches. Message numbers are per folder and per session;
re-run the search rather than reusing numbers from an earlier day.

## Links inside mails

- Kickstarter and many shops wrap every link in a click-tracking redirect.
  Often the redirect path is base64 JSON whose `href` field is the real URL.
- Creator updates often carry the important link (a tracking sheet) as plain
  text in the HTML body rather than as an `href`; search the decoded body for
  `docs.google.com`.
