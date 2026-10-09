# timesamurai: finding and changing entries

## Finding entries (list / search)

```bash
timesamurai work list [range] [filters]
timesamurai work search <text> [filters]     # case-insensitive substring in descr
```

Shared filters: `--since` / `--until` (inclusive time bounds, same formats
as `--at`), `--min` / `--max` (inclusive value bounds, durations like `1h`,
`8h`), `--tag work`, `--action add`, `--host earth`, `--limit 20` (0 =
unlimited). `list` additionally has `-d/--descr` (description contains
text). Add `--format json` for machine-readable output: the file's fields
plus an `address` (`host:id`) field on each row.

Table output looks like:

```
ADDRESS          ACTION  WHEN                 VALUE  TAGS   DESCR
earth:146        add     2023-03-23 10:34:50  7200   selfdevelopment  Podcasts
```

The **ADDRESS column (`host:id`) is the key to modify/delete**. Copy it
verbatim from the output; never invent ids. Rows are sorted **oldest first**,
and `--limit N` keeps the N *oldest* rows — so to see recent entries use
`--since` (or `search`), not `--limit`. `list` without a range spans all
hosts, so always combine a range or `--since` with `--limit`.

## Changing entries (modify / delete / undo / edit)

```bash
timesamurai work modify <host:id> [--action login|logout|add] [--at time]
                       [-d descr] [--value 1h] [--tags work,pet]
timesamurai work delete <host:id> [<host:id> ...] [--dry-run]
timesamurai work undo [--host <name>]
timesamurai work edit [range]
```

- `modify` changes **only** the flags you pass. `--tags` is comma-separated
  and **replaces** the whole tag list (it does not append). `--value` is a
  signed duration or bare seconds. Host and id can never be changed.
- `delete` accepts several addresses, but a multi-address delete without
  `--dry-run` asks for interactive confirmation (`[y/N]`) — it can hang or
  cancel in a non-interactive context. Run with `--dry-run` first when unsure.
- `undo` reverts exactly **one** change, LIFO: the newest insert/modify/delete
  **made from this machine** (searching all hosts' undo logs).
  `undo --host X` instead pops the newest change in **X's** log, no matter
  which machine made it. It is not a general "undo last N".
- `edit` opens entries in `$EDITOR` as a text block for a range.

Typical fix flow:

1. `timesamurai work search "thing"` (or `list` with filters)
2. Read the `host:id` address from the table
3. `timesamurai work modify <host:id> --value 2h --tags work`
4. Verify the entry: `timesamurai work list --since <the entry's date> --limit 20`
   and check the row for your `host:id` — `--since` must be on or before the
   entry's date, otherwise it won't show (plain `list --limit N` shows the N
   oldest entries across all hosts, not the one you just changed)
5. If it was wrong: `timesamurai work undo`
