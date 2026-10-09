---
name: protonbridge
description: "Proton Mail through Proton Bridge: read, list, search, count or fetch mail over local IMAP (STARTTLS on 127.0.0.1 port 1143, credentials from ~/.protonbridge), and manage the aerc connection to the Bridge running in the f3s k3s cluster (kubectl port-forward tunnel, pinned certificate, systemd user service). Use for inbox or folder questions, aerc setup, certificate or login errors, and the protonbridge-k3s-tunnel service. Triggers on: protonbridge, proton bridge, proton mail, protonmail, imap, list emails, read inbox, aerc mail, Proton Bridge tunnel, aerc IMAP, aerc SMTP."
---

# Proton Bridge

Proton Mail is reached through Proton Mail Bridge, which runs in the f3s k3s
cluster and is exposed on `earth` by a persistent port-forward: IMAP on
`127.0.0.1:1143` and SMTP on `127.0.0.1:1025`, both STARTTLS.

Never print the Bridge-generated password, and never commit it.

## When to Use

- Reading, listing, searching, counting or fetching mail, checking the inbox, listing folders
- Setting up, starting, validating or troubleshooting aerc against the Bridge
- Certificate errors, rejected logins, a rotated Bridge password, or a dead tunnel

## Reference Files

Load the one that matches the task:

- [IMAP access](references/imap.md) — reading mail with Python `imaplib`: loading `~/.protonbridge`, connecting with STARTTLS (not `IMAP4_SSL`), listing folders, searching, fetching without marking as read, a one-shot shell helper, IMAP troubleshooting
- [aerc and the tunnel](references/aerc.md) — the path from aerc to the Bridge pod: architecture, canonical files, the f3s Argo CD deployment, bootstrap order, the expected aerc account, starting and inspecting the `protonbridge-k3s-tunnel` service, end-to-end health check, recreating the tunnel, refreshing credentials and the pinned certificate, troubleshooting order

## Quick Reference

- Load credentials in a shell: `set -a; . ~/.protonbridge; set +a` (the file uses command substitution, so a plain `KEY=VALUE` parser will not get the password)
- The password lives in one place only: `~/.config/aerc/protonbridge-password` (mode `0600`); refreshing it is in the aerc reference
- `Connection refused` on 1143 means the tunnel is down: see the aerc reference
- `no such user` right after a Bridge pod restart usually clears by itself within a few minutes
- Cluster access, Argo CD and node problems: the f3s [k3s area index](../f3s/references/k3s.md)
