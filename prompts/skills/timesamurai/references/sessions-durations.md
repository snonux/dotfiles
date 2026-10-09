# timesamurai: sessions and durations

## Sessions (start / stop / status)

- `start` writes a `login` entry (value 0) for the tag category — default `work`.
- `stop` writes a `logout` entry (value 0). The report computes the duration.
- Only **one** open session per tag category exists across all hosts:
  - `start` while one is open → error `already logged in`.
  - `stop` while none is open → error `not logged in`.
- `start`/`stop` accept tags as arguments: `timesamurai work start lunch`
  opens a lunch session. Default (no tags) is `work`.
- `-d/--descr` adds a free-text description to the entry.
- `--at` backdates the entry (see [time formats](formats-tags.md)).

Check `timesamurai work status` before suggesting `start` if the user's
request implies a session may already be open.

## Durations (add / sub / usebuffer)

```bash
timesamurai work add <duration> [tags...] [-d descr] [--at time]
timesamurai work sub <duration> [tags...] [-d descr] [--at time]
timesamurai work usebuffer <duration> [-d descr] [--at time]
```

Duration formats:

- `30m`, `1h`, `1h30m`, `2.5h`, `45s` — Go duration syntax (unit letters case-insensitive).
- **A bare integer is SECONDS**, not minutes: `3600` = 1 hour, `60` = 1 minute.
  When a user says "60", ask or assume minutes and use `60m`.
- `add` must be positive; `sub` is a withdrawal (writes a negative value).
- Default tag is `work`. Extra tags are positional: `add 1h30m pet`.
- `usebuffer` is always selfdevelopment → work, two `add` entries.
