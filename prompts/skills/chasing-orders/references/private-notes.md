# Private Notes

Everything specific to Paul's orders is private and lives outside this skill,
in the Syncthing notes vault:

| Note | Contents |
|---|---|
| `~/Notes/OrderStatus.md` | Dated snapshot of open orders: action items, promised dates, states, backer numbers, account mail aliases, reference ids |
| `~/Notes/OrderVendors.md` | Per-seller how-to: mail sender and subject patterns, order-portal URLs and endpoints, how each seller ships and reports status |

## The rule

The skills directory (`~/Notes/Prompts/skills`) is a symlink into the dotfiles
git repository, which is public. **Nothing that identifies an order or a
seller may be written anywhere under the skill**: no seller, shop, creator or
product names, no seller URLs or endpoints, no order, backer or tracking
numbers, no order-page links, prices, account mail aliases or addresses. Use
neutral placeholders in examples. Generic services (the mail bridge, a
crowdfunding platform's page structure, spreadsheet exports, tracking sites)
are fine.

## Using the notes

1. Read both notes at the start of a run. The status note says what is open
   and which numbers and project slugs to look up; the vendor note says where
   each seller keeps its data.
2. If a note is missing, rebuild it by running the full
   [workflow](workflow.md): the status note from the section list below, the
   vendor note from whatever the run learns about each seller.
3. At the end of a run rewrite the status note in place: new snapshot date,
   new states, follow-ups sent with their date, orders Paul confirmed as
   received removed.
4. When a new seller's portal or mail pattern is worked out, add it to the
   vendor note, and add only the seller-independent lesson to this skill.
5. Keep both notes at mode `600`.

Links that open an order without a login (such as an order page with an id in
the query string) do not belong in either note; record how to recover them
instead.

## Layout of the status note

- Snapshot date
- Account mail aliases per platform
- Open action items (what Paul has to do, per order)
- Orders outside the crowdfunding platform: ordered, promised, current state
- Physical pledges not marked shipped: backer number, pledge, estimate, latest
  update, state
- Pledges the creator marked shipped, received orders, and other notes
- Reference ids (tracking sheet ids, project slugs)
