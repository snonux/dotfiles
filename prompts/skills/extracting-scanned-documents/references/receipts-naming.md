# Purchase receipts / invoices — naming

```
YYYY-MM-DD-receipt-<store>-<item-description>-<amount><currency>.pdf
```

## Rules

- **Date**: Purchase/transaction date in `YYYY-MM-DD` format.
- **Prefix**: Always `receipt` (or `invoice` if the document is an invoice/Rechnung).
- **Store**: Lowercase short name of the merchant (e.g., `technopolis`, `ikea`, `amazon`).
- **Item description**: Brief lowercase hyphen-separated description of what was purchased (e.g., `krups-coffee-machine`, `samsung-tablet`, `office-chair`). Keep it short but identifiable.
- **Amount**: Numeric amount with currency suffix (`bgn`, `eur`, `gbp`, `usd`). Omit if the page is a packing list or supplementary page without a total.
- **Suffixes**: Use `-warranty`, `-packing-list`, `-delivery-note`, etc. for supporting pages.
- All lowercase, no spaces, hyphens as separators.

## Examples

```
2025-01-24-receipt-technopolis-mall-serdika-krups-coffee-machine-132.40eur.pdf
2023-05-27-receipt-technopolis-24inch-lg-tv-zapaden-park.pdf
2024-09-01-receipt-ikea-mol-sofia.pdf
2022-09-08-invoice-chair-pro.pdf
2024-05-17-packing-list-macbook-pro.pdf
```

## Notes

- When a single page contains multiple items from the same store, name after the most significant/expensive item or use a combined description (e.g., `lg-tv-and-philips-purifier`).
- Include store location in the name only when it adds useful context (e.g., `mall-serdika`, `mol-sofia`).
- For warranty extension documents, include `-warranty` suffix.
- For delivery/packing lists, use `packing-list` or `delivery-note` as the prefix instead of `receipt`.
