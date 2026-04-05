---
name: extracting-scanned-receipts
description: "Extracts individual pages from scanned multi-page PDF purchase receipts and invoices, naming each file by date, store, item description, and amount. Use when asked to extract, split, or organize scanned purchase receipts, shop receipts, or invoices from PDFs. Triggers on: extract receipts, split receipts, organize invoices, scanned receipts, purchase receipts."
---

# Extracting Scanned Receipts

Split multi-page scanned PDFs of purchase receipts and invoices into individually named single-page files using content-based naming.

## Prerequisites

- `pdftk` or `qpdf` must be installed for PDF splitting.
- Use `qpdf --show-npages <file>` to get page counts.
- Use `pdftk <file> cat <page> output <dest>` to extract single pages.

## Workflow

### 1. Inventory

Count pages in each PDF:

```sh
for f in *.pdf; do echo "$f: $(qpdf --show-npages "$f") pages"; done
```

### 2. Analyze content

Use `look_at` on each PDF with this objective:

> For each page, identify: exact purchase date, what was purchased (item names, product descriptions), amount with currency, store/merchant name and location, any order/receipt/invoice numbers, and person names. List every detail page by page.

Analyze all PDFs in parallel when there are multiple files.

### 3. Name each page

Apply this naming convention:

```
YYYY-MM-DD-receipt-<store>-<item-description>-<amount><currency>.pdf
```

**Rules:**
- **Date**: Purchase/transaction date in `YYYY-MM-DD` format.
- **Prefix**: Always `receipt` (or `invoice` if the document is an invoice/Rechnung).
- **Store**: Lowercase short name of the merchant (e.g., `technopolis`, `ikea`, `amazon`).
- **Item description**: Brief lowercase hyphen-separated description of what was purchased (e.g., `krups-coffee-machine`, `samsung-tablet`, `office-chair`). Keep it short but identifiable.
- **Amount**: Numeric amount with currency suffix (`bgn`, `eur`, `gbp`, `usd`). Omit if the page is a packing list or supplementary page without a total.
- **Suffixes**: Use `-warranty`, `-packing-list`, `-delivery-note`, etc. for supporting pages.
- All lowercase, no spaces, hyphens as separators.

**Examples:**
```
2025-01-24-receipt-technopolis-mall-serdika-krups-coffee-machine-132.40eur.pdf
2023-05-27-receipt-technopolis-24inch-lg-tv-zapaden-park.pdf
2024-09-01-receipt-ikea-mol-sofia.pdf
2022-09-08-invoice-chair-pro.pdf
2024-05-17-packing-list-macbook-pro.pdf
```

### 4. Extract pages

Create the destination directory if needed, then extract:

```sh
mkdir -p <dest>
pdftk <source>.pdf cat <page> output <dest>/<named-file>.pdf
```

### 5. Report

After extraction, list all files in the destination and report the total count plus a brief summary of what was extracted (date range, stores, items).

## Notes

- When a single page contains multiple items from the same store, name after the most significant/expensive item or use a combined description (e.g., `lg-tv-and-philips-purifier`).
- Include store location in the name only when it adds useful context (e.g., `mall-serdika`, `mol-sofia`).
- For warranty extension documents, include `-warranty` suffix.
- For delivery/packing lists, use `packing-list` or `delivery-note` as the prefix instead of `receipt`.
- Always preserve the original scanned PDFs — never modify or delete them.
