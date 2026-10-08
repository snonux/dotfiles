# Workflow

The order of work that produces a complete picture. Each step narrows what
the next one has to check.

## 1. Start from the snapshot

Read `~/Notes/OrderStatus.md` and `~/Notes/OrderVendors.md` first (see
[private-notes.md](private-notes.md)). The first lists the open orders, their
backer numbers and the last known state, so a run only has to look for what
changed since the snapshot date; the second says where each seller keeps its
order data.

## 2. Mail

See [mail-search.md](mail-search.md).

1. List `Folders/Kickstarter` (headers only), then read the newest message of
   each project thread.
2. Search `Archive`, `INBOX`, `Sent` and `Trash` for the same senders and
   project names. Shipping confirmations and Paul's own correspondence with
   sellers are normally filed outside the Kickstarter folder.
3. Note for each order: what was promised and when, the last thing the seller
   said, and whether a shipping or tracking mail exists.

## 3. Vendor portals and tracking lists

See [vendor-portals.md](vendor-portals.md). Use them whenever mail shows no
shipment. Two kinds of finding only show up here:

- An order that looks months late in mail has in fact been delivered; the
  portal has the full tracking history.
- An order has never been confirmed on the portal, which is why it has not
  shipped.

## 4. Kickstarter and other crowdfunding sites

See [kickstarter.md](kickstarter.md). Needed for anything behind a login:
backer numbers, creator-reported status, backers-only updates, pending
surveys. Ask Paul to log in; the Chrome extension must be connected to the
session (`/chrome`).

Read the whole backed-projects list, not only the projects that appear in
mail: it surfaces overdue physical pledges that have no mail in the
Kickstarter folder at all.

## 5. Classify

Give every order exactly one state:

| State | Meaning |
|---|---|
| Needs action | Blocked on Paul: unconfirmed order, unanswered survey, unpaid shipping or duties |
| Overdue | Past the seller's own date with no shipment and nothing for Paul to do but chase |
| In progress | Shipping in batches or by backer number; Paul's turn has not come yet |
| Not due | Seller's current date is still in the future |
| Delivered | Tracking or Paul confirms receipt |

"Due" always means the seller's most recent stated date, not the original
campaign estimate. Kickstarter's "Estimated delivery" is the campaign estimate
and is rarely updated, so read the latest update before calling a pledge late.

Digital rewards are not deliveries. Filter them out of the Kickstarter list
(reward names containing "digital", "PDF", "Dig") unless Paul asks.

## 6. Report

Lead with what needs Paul's action, then delivered, overdue, in progress, not
due. Say what was not checked (folders skipped, pages that needed a login).
State an estimate of your own as an estimate: for example, a ship date derived
from "backers 1–100 shipped, 36 units a week" is arithmetic, not the creator's
promise.

Paul often already has an item that the site still shows as outstanding
(creators rarely mark pledges shipped). Ask before chasing anything that the
latest update says has shipped.

## 7. Follow up

Only on request. See [follow-up-mail.md](follow-up-mail.md). Opening tabs for
the action items is a useful hand-off: one tab per item, left open.

## 8. Update the snapshot

Rewrite `~/Notes/OrderStatus.md` with the new date and states. Drop orders
Paul confirms as received. Add anything learned about a seller's portal or
mail to `~/Notes/OrderVendors.md`. Keep all of it in the notes, never in the
skill.
