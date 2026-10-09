---
name: chasing-orders
description: "Chases overdue crowdfunding pledges and pre-orders via Proton Mail, Kickstarter and seller portals, and follows up with sellers. Use when asked which deliveries are due or late, where an order is, or for a backer or tracking number. Triggers on: chase orders, deliveries due, overdue orders, where is my order, shipping status, tracking status, backer number, kickstarter deliveries, pre-order status, order follow-up."
---

# Chasing Orders

Find out which crowdfunding rewards and pre-orders are overdue, shipped, or
blocked on an action from Paul, and follow up with the seller where needed.
Everything is read-only by default; sending mail or changing anything on a
site needs Paul's explicit request.

## When to Use

- "Any deliveries due?" / "Which orders are late?" / "Where is my X?"
- Finding a Kickstarter backer number, a tracking number, or a missed survey
- Checking the live status of a pledge, pre-order, or shipment
- Emailing a seller to ask about an overdue delivery
- Refreshing the status snapshot of open orders

## Reference Files

Load the one that matches the task:

- [Workflow](references/workflow.md) — the order of work (mail → portals → Kickstarter → verdict → follow-up), how to classify each order, what counts as "due", and how to report.
- [Mail search](references/mail-search.md) — which folders hold order mail, the generic sender and subject patterns, the Bridge search pitfalls (All Mail timeouts, stale password file), and how to use `scripts/imap_search.py`.
- [Kickstarter](references/kickstarter.md) — logging in through Chrome, the backed-projects page, reading a pledge's backer number / status / latest update, pending survey banners, and the page-scripting snippets that work.
- [Vendor portals](references/vendor-portals.md) — the generic method: order pages backed by a JSON API, tracking pages, tracking lists published as Google Sheets (`scripts/xlsx_grep.py`), Shopify order pages, creator blogs, other crowdfunding sites.
- [Follow-up mail](references/follow-up-mail.md) — replying in the seller's existing thread through Bridge SMTP, which From address to use, wording, and verifying the copy in Sent.
- [Private notes](references/private-notes.md) — the two notes outside this public repo (`~/Notes/OrderStatus.md` for the snapshot of open orders, `~/Notes/OrderVendors.md` for per-seller how-to), their layout, and the rule that no order or seller detail goes into the skill.

## Scripts

- `scripts/imap_search.py` — read-only IMAP search over one or more folders with a fresh connection per folder; prints header lines or bodies.
- `scripts/xlsx_grep.py` — stdlib-only `.xlsx` reader that prints the rows matching a pattern (for creator tracking lists).

## Quick Reference

- Mail access: [`protonbridge-imap`](../protonbridge-imap/SKILL.md); tunnel and the working password file: [`protonbridge-aerc`](../protonbridge-aerc/SKILL.md).
- Order mail lives in `Folders/Kickstarter`, but shipping notices are usually in `Archive`; always search both.
- Open orders are in `~/Notes/OrderStatus.md`, seller specifics in `~/Notes/OrderVendors.md`; read both first, update them last. Never name a seller or copy order data into this skill (public repo).
- A missing shipping mail is not proof of "not shipped": check the vendor portal or the creator's tracking list before calling an order overdue.
- Kickstarter pledge page: `https://www.kickstarter.com/projects/<creator>/<slug>/backing/details`.
- Paul logs in himself; never type credentials or solve bot checks.
