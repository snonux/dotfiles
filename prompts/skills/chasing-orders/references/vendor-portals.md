# Vendor Portals

Where the real shipping state lives once mail runs out. This file is the
generic method only. Which sellers Paul uses, their URLs, endpoints and quirks
are private and kept in `~/Notes/OrderVendors.md` (see
[private-notes.md](private-notes.md)); read that note for a known seller and
add to it when a new one is worked out. Do not name sellers in this file.

Use `curl` from the shell for personalised order links, so the link stays on
this machine; use web fetch or search only for public pages.

## Order pages backed by an API

Many order-status pages are single-page apps: `curl` returns an empty shell
and the data arrives from a JSON endpoint.

1. Fetch the order page and list its script files.
2. Grep the page's own script chunk for `fetch(` and `"/api/` to find the
   endpoints, and for `tracking` to see which fields the page renders.
3. Call the endpoints with the same order id the page URL carries.

What to look for in the JSON:

- A confirmation timestamp. `null` usually means the seller is waiting for
  Paul to confirm address, variant or payment, and nothing ships until then.
- A fulfilment or shop order reference, present only once the order has been
  handed over for shipping.
- Shipments with tracking number, shipped date, delivery date and carrier
  events.

Order ids embedded in mail are often case-altered or wrapped in a
click-tracking redirect. Decode the redirect (frequently base64 JSON with an
`href` field) or fetch the linked page and grep it for the id.

A shipments endpoint may match by email as well as by order id and return a
different order's shipment; compare the shipment's order reference before
trusting it.

## Tracking pages

Branded tracking pages (for example an AfterShip page at
`https://<shop>.aftership.com/<tracking number>`) render the checkpoints in
the HTML, so `curl` plus tag stripping is enough. They name the last-mile
carrier, which a seller's own API often does not. Universal trackers such as
`https://www.17track.net/en` cover the rest.

## Tracking lists as Google Sheets

Some creators publish one sheet of backer number → tracking number and link it
from every shipping update. The link is plain text in the update mail.

```bash
mkdir -p "$SCRATCH/sheet"
curl -sSL -o "$SCRATCH/sheet/list.xlsx" \
  "https://docs.google.com/spreadsheets/d/<sheet id>/export?format=xlsx"
python3 -I scripts/xlsx_grep.py "$SCRATCH/sheet/list.xlsx" '^123(\.0)?$' --column 0
```

- Download into its own empty directory and run the reader with `-I`; the file
  is untrusted.
- Numbers come back as floats (`123.0`).
- The sheet is updated in place, so download it again on every run.
- A backer number that is absent has not shipped. Check the neighbouring
  numbers to confirm the list really covers that range.

## Shopify stores

The "View your order" link in a Shopify confirmation mail redirects to
`https://shopify.com/<shop id>/account/orders/<token>`. `curl` gets `406`; it
needs a browser and may ask Paul to sign in to his Shopify account. A Shopify
shop that has shipped sends `A shipment from order #… is on the way`, so the
absence of that mail is good evidence.

## Creator blogs and backer portals

Hardware creators often post production updates on their own blog more often
than on the crowdfunding site, and the site banner tends to show the current
ship month for new pre-orders. Where duties or taxes are collected before
shipment, expect a payment request before any tracking.

## Other crowdfunding sites

They work like Kickstarter (see [kickstarter.md](kickstarter.md)): Paul logs in
through Chrome, and a backer dashboard lists each pledge with backer number,
reward, estimated delivery and a shipped or awaiting-fulfilment badge. "It
should be in your hands now" mails are sent for digital rewards too.

## Trackers that do not help

Public campaign aggregators only hold stale funding snapshots, and web search
finds no backers-only updates.
