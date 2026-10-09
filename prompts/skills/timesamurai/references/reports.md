# timesamurai: reports

## Reports

```bash
timesamurai work report            # full history
timesamurai work report [range]    # one range
```

Range formats (all inclusive of their natural boundaries):

- `today`, `yesterday`
- `week` — the current ISO week (Monday start; **not** the last 7 days)
- `lastweek`
- `month` — the current calendar month
- `YYYY-MM` — e.g. `2026-08`
- `YYYY-MM-DD..YYYY-MM-DD` — e.g. `2026-09-01..2026-09-07` (both days included)

Output is per-day lines (e.g. `Tue 20260908 37: work:6.69h`) plus a week
totals line. Both always print `work:` (even at zero) and the other fixed
categories — `balance`, `lunch`, `off`, `sick`, `bank`, `pet`,
`selfdevelopment` — only when non-zero, in that order; the week totals line
additionally always ends with a `buffer:` token. `balance` is the running
total against the weekly target (default 40h/week, from config). A `*`
before a day marks a weekend or a day with ≥8h off **or** ≥8h bank.

To answer "how many hours this week?" run `work report week` and read the
totals line. To answer "today?" run `work report today`. A range with no
entries prints nothing (exit 0) — that means "no time recorded", not an
error.
