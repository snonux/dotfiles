# Bills / utilities / payments — naming

```
YYYY-MM-DD-<type>-<address-short>-<amount><currency>.pdf
```

## Rules

- **Date**: Transaction date in `YYYY-MM-DD` format.
- **Type**: Lowercase, hyphen-separated description of what the bill is for (e.g., `electricity`, `water`, `heating`, `property-tax-and-waste`, `health-insurance`, `speeding-fine`, `parking-fine`).
- **Address**: Short form of the service address (e.g., `sofia-zapaden-park-bl100`, `vidin-himik-bl25`, `podgore-zdravkov14`). Use `and` to join when a single receipt covers multiple addresses.
- **Amount**: Numeric amount with currency suffix (`bgn`, `eur`). Omit if the page is an annex/appendix without its own total.
- **Suffixes**: Use `-card-slip`, `-payment-summary`, `-annex-p1`, `-annex-p2`, etc. for supporting pages.
- All lowercase, no spaces, hyphens as separators.

## Examples

```
2026-02-26-electricity-heating-sofia-zapaden-park-bl100-81.02eur.pdf
2025-08-21-speeding-fine-sofia-alek-konstantinov38-cb9625xp-50bgn.pdf
2025-10-09-health-insurance-egn7411271790-receipt-51.84bgn.pdf
2026-02-02-property-tax-and-waste-annex-p2-sofia-zapaden-park-bl100-and-alek-konstantinov38.pdf
2025-12-01-easypay-payment-summary-72.94bgn.pdf
```

## Notes

- When a single page contains multiple receipts for different addresses, include all addresses in the filename joined with `and`.
- For fines, include the vehicle plate number in the filename (e.g., `cb9625xp`).
- For health insurance, include the EGN identifier.
- For property tax / waste fees that span multiple pages (receipt + annexes), keep them as separate files but use consistent naming with annex suffixes.
