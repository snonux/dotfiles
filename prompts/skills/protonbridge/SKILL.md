---
name: protonbridge
description: "Reads Proton Mail over the local Proton Bridge IMAP port and manages the aerc connection to the Bridge in the f3s k3s cluster (tunnel, pinned certificate, credentials). Use for inbox or folder questions, full mail backups or exports, aerc setup, and login or certificate errors. Triggers on: protonbridge, proton mail, protonmail, imap, list emails, read inbox, aerc mail, Proton Bridge tunnel, backup mail, export mail."
---

# Proton Bridge

Proton Mail is reached through Proton Mail Bridge, which runs in the f3s k3s
cluster and is exposed on `earth` by a persistent port-forward: IMAP on
`127.0.0.1:1143` and SMTP on `127.0.0.1:1025`, both STARTTLS.

Never print the Bridge-generated password, and never commit it.

## When to Use

- Reading, listing, searching, counting or fetching mail, checking the inbox, listing folders
- Backing up or exporting all mail to a local directory
- Setting up, starting, validating or troubleshooting aerc against the Bridge
- Certificate errors, rejected logins, a rotated Bridge password, or a dead tunnel

## Reference Files

Load the one that matches the task:

- [IMAP access](references/imap.md) — reading mail with Python `imaplib`: loading `~/.protonbridge`, connecting with STARTTLS (not `IMAP4_SSL`), listing folders, searching, fetching without marking as read, a one-shot shell helper, IMAP troubleshooting
- [aerc and the tunnel](references/aerc.md) — the path from aerc to the Bridge pod: architecture, canonical files, the f3s Argo CD deployment, bootstrap order, the expected aerc account, starting and inspecting the `protonbridge-k3s-tunnel` service, end-to-end health check, recreating the tunnel, refreshing credentials and the pinned certificate, troubleshooting order
- [Backup](references/backup.md) — exporting every mailbox to `.eml` files with `scripts/export_mailboxes.py`: sizing the job, running it in the background, the resulting layout and manifests, resuming, the wedged port-forward on large messages, verifying the result

## Quick Reference

- Load credentials in a shell: `set -a; . ~/.protonbridge; set +a` (the file uses command substitution, so a plain `KEY=VALUE` parser will not get the password)
- The password lives in one place only: `~/.config/aerc/protonbridge-password` (mode `0600`); refreshing it is in the aerc reference
- `Connection refused` on 1143 means the tunnel is down: see the aerc reference
- `no such user` right after a Bridge pod restart usually clears by itself within a few minutes
- Cluster access, Argo CD and node problems: the f3s [k3s area index](../f3s/references/k3s.md)
