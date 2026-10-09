# timesamurai: time formats, tags and accounting

## Time formats (`--at`, `--since`, `--until`)

All accept:

- Clock time: `9:30` or `9:30:05` — always applied to **today**.
- `today`, `yesterday` — midnight of that day.
- ISO-8601 / RFC3339: `2026-09-12T14:30:00Z` (or with offset).
- Local date/time: `2026-09-12`, `2026-09-12T14:30`, `2026-09-12 14:30:05`.
- Relative offsets from now: `-2h`, `+30m`, `-24h`. Only `h`/`m`/`s` units
  work — there is no `d`; use `-24h` for a day.
- A bare integer is **unix epoch seconds** (not a clock time).

Defaults: `--at` is now; `--since`/`--until` are inclusive bounds.

## Tags and accounting

Default configuration categories (see config for the live lists):

- `work` — default tag; worked time.
- `lunch` — subtracted from the report (minus category).
- `off`, `sick`, `bank`, `bufferuse` — added as positive (plus category).
- Buffer categories: `tools`, `pet`, `selfdevelopment`, `workrebalance`,
  `compensate`, `travel`, `rebalance` — tracked separately, movable into
  work via `usebuffer` (only `selfdevelopment` is drawn by `usebuffer`).
- Any other tag is a label; it is stored but not accounted.

An entry gets **one** primary accounting tag (work/plus/minus). If you pass
several primary tags, the command errors (`multiple accounting tags`).
Buffer tags can ride along as extra labels.
