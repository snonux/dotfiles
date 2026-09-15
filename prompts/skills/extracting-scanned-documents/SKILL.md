---
name: extracting-scanned-documents
description: "Extracts individual pages from scanned multi-page PDF bills, receipts, and invoices, naming each file from page content (date, type/store, address or items, amount). Use when asked to extract, split, or organize scanned bills, utility receipts, utility/payment documents, purchase receipts, shop receipts, or invoices from PDFs. Triggers on: extract bills, extract receipts, split scans, split receipts, organize receipts, organize invoices, scanned documents, scanned receipts, purchase receipts, utility receipts."
---

# Extracting Scanned Documents

Split multi-page scanned PDFs into individually named single-page files using content-based naming. Covers utility/payment bills and purchase receipts/invoices.

## Prerequisites

- `pdftk` or `qpdf` must be installed for PDF splitting.
- Use `qpdf --show-npages <file>` to get page counts.
- Use `pdftk <file> cat <page> output <dest>` to extract single pages.

## Naming references

Load the naming convention that matches the document type (do not mix patterns on the same page):

- [Bills / utilities / payments](references/bills-naming.md) — date, bill type, address, amount
- [Purchase receipts / invoices](references/receipts-naming.md) — date, store, item description, amount

## Workflow

### 1. Inventory

Count pages in each PDF:

```sh
for f in *.pdf; do echo "$f: $(qpdf --show-npages "$f") pages"; done
```

### 2. Analyze content

Use `look_at` on each PDF. Classify each page as a **bill/payment** or **purchase receipt/invoice**, then gather the fields needed for that naming reference.

Bill/payment objective:

> For each page, identify: exact transaction date, what the payment is for (utility type, tax, fine, insurance, etc.), amount with currency, any client/account numbers, addresses, and person names. List every detail page by page.

Purchase receipt/invoice objective:

> For each page, identify: exact purchase date, what was purchased (item names, product descriptions), amount with currency, store/merchant name and location, any order/receipt/invoice numbers, and person names. List every detail page by page.

Analyze all PDFs in parallel when there are multiple files.

### 3. Name each page

Apply the matching naming reference from [Naming references](#naming-references) above. All filenames: lowercase, no spaces, hyphens as separators.

### 4. Extract pages

Create the destination directory if needed, then extract:

```sh
mkdir -p <dest>
pdftk <source>.pdf cat <page> output <dest>/<named-file>.pdf
```

### 5. Report

After extraction, list all files in the destination and report the total count plus a brief summary (date range, document kinds, addresses/stores covered).

## Notes

- Always preserve the original scanned PDFs — never modify or delete them.
- A mixed scan batch can contain both bill and receipt pages; name each page with the convention that fits that page.
