---
name: extracting-scanned-bills
description: "Extracts individual pages from scanned multi-page PDF bills and receipts, naming each file by date, type, address, and amount. Use when asked to extract, split, or organize scanned bills, utility receipts, or payment documents from PDFs. Triggers on: extract bills, split scans, organize receipts, scanned documents."
---

# Extracting Scanned Bills

Split multi-page scanned PDFs into individually named single-page files using content-based naming.

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

> For each page, identify: exact transaction date, what the payment is for (utility type, tax, fine, insurance, etc.), amount with currency, any client/account numbers, addresses, and person names. List every detail page by page.

Analyze all PDFs in parallel when there are multiple files.

### 3. Name each page

Apply this naming convention:

```
YYYY-MM-DD-<type>-<address-short>-<amount><currency>.pdf
```

**Rules:**
- **Date**: Transaction date in `YYYY-MM-DD` format.
- **Type**: Lowercase, hyphen-separated description of what the bill is for (e.g., `electricity`, `water`, `heating`, `property-tax-and-waste`, `health-insurance`, `speeding-fine`, `parking-fine`).
- **Address**: Short form of the service address (e.g., `sofia-zapaden-park-bl100`, `vidin-himik-bl25`, `podgore-zdravkov14`). Use `and` to join when a single receipt covers multiple addresses.
- **Amount**: Numeric amount with currency suffix (`bgn`, `eur`). Omit if the page is an annex/appendix without its own total.
- **Suffixes**: Use `-card-slip`, `-payment-summary`, `-annex-p1`, `-annex-p2`, etc. for supporting pages.
- All lowercase, no spaces, hyphens as separators.

**Examples:**
```
2026-02-26-electricity-heating-sofia-zapaden-park-bl100-81.02eur.pdf
2025-08-21-speeding-fine-sofia-alek-konstantinov38-cb9625xp-50bgn.pdf
2025-10-09-health-insurance-egn7411271790-receipt-51.84bgn.pdf
2026-02-02-property-tax-and-waste-annex-p2-sofia-zapaden-park-bl100-and-alek-konstantinov38.pdf
2025-12-01-easypay-payment-summary-72.94bgn.pdf
```

### 4. Extract pages

Create the destination directory if needed, then extract:

```sh
mkdir -p <dest>
pdftk <source>.pdf cat <page> output <dest>/<named-file>.pdf
```

### 5. Report

After extraction, list all files in the destination and report the total count plus a brief summary of what was extracted (date range, types of documents, addresses covered).

## Notes

- When a single page contains multiple receipts for different addresses, include all addresses in the filename joined with `and`.
- For fines, include the vehicle plate number in the filename (e.g., `cb9625xp`).
- For health insurance, include the EGN identifier.
- For property tax / waste fees that span multiple pages (receipt + annexes), keep them as separate files but use consistent naming with annex suffixes.
- Always preserve the original scanned PDFs — never modify or delete them.
