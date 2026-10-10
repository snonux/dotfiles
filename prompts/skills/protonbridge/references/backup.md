# Backing up all Proton mail

This reference covers a full export of every mailbox to `.eml` files through
the Bridge IMAP port, using [`scripts/export_mailboxes.py`](../scripts/export_mailboxes.py).

Proton's official export tool is not used: it needs an interactive login with
the Proton account password and 2FA, which must never be requested or
retained. The Bridge session in the cluster is already authenticated.

## Before starting

1. Confirm the tunnel listens and a login works (see [IMAP access](imap.md)).
2. Size the job: `SELECT` each mailbox read-only and sum `RFC822.SIZE` from
   `FETCH 1:* (RFC822.SIZE)`. `All Mail` alone is roughly the size on disk,
   because the other mailboxes mostly hardlink to it.
3. Check free space on the destination with `df -h`.
4. Agree the destination directory with the user if they did not name one.

## Run

The export takes hours, so run it in the background and log to a file. `-I`
keeps Python from importing anything from the current directory.

```bash
set -a; . ~/.protonbridge; set +a
python3 -I ~/.claude/skills/protonbridge/scripts/export_mailboxes.py DEST_DIR \
  >> export.log 2>&1
```

The script only reads: every mailbox is selected read-only and messages are
fetched with `BODY.PEEK[]`, so nothing is marked as read or moved.

## Result

```text
DEST_DIR/
  INBOX/
    manifest.tsv
    2026-07-20_0000023_Some_subject.eml
  All Mail/
  Folders/<name>/
  Labels/<name>/
```

- One directory per selectable mailbox; `/` in a mailbox name becomes a
  subdirectory.
- File names are `<internal date>_<uid>_<subject>.eml`; the file mtime is the
  IMAP internal date.
- `manifest.tsv` has one line per message: UID, SHA-256, IMAP flags, file name.
  The flags (`\Seen`, `\Flagged`, ...) exist only there, not in the `.eml`.
- Every mailbox is exported in full. A message that Proton shows in several
  mailboxes (its folder, `All Mail`, labels, `Starred`) is stored once and
  hardlinked, so `du` reports far less than the sum of the mailbox sizes.
  Copy the tree with a tool that preserves hardlinks (`rsync -aH`, `tar`).
- `All Mail` can hold more messages than all folders together, so do not skip
  it to save time.

## Resume and failures

- Re-running with the same `DEST_DIR` resumes: UIDs already in a manifest whose
  file still exists are skipped. It is also how to refresh an older backup
  with new mail. Messages deleted in Proton stay in the backup.
- The `kubectl port-forward` can wedge on large messages (tens of MB): the
  local port keeps listening, but every new connection gets `socket error:
  EOF` and the tunnel journal shows `error creating error stream ... Timeout
  occurred`. The pod is healthy in that state. The script retries each message
  five times and restarts `protonbridge-k3s-tunnel.service` itself when a
  reconnect fails; aerc drops its connection briefly each time.
- A message that still fails after the retries is logged and skipped, and the
  script exits with status 1. Re-run to try those again.

## Verify

- The last log line is `DONE: <n> exported, <failed> failed, <unique> unique
  messages`; `failed` must be 0.
- Per mailbox, the number of lines in `manifest.tsv` must equal the message
  count IMAP reports for it:

```bash
find DEST_DIR -name manifest.tsv -exec wc -l {} +
```

- No `*.part` files may remain; one is a write that was interrupted.
