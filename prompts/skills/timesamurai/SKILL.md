---
name: timesamurai
description: "Use the timesamurai CLI to track work time — start/stop work sessions, add/subtract hours, day off, time reports, and find/modify/delete/undo log entries. Use when asked to log work time, clock in/out, add hours, record a lunch or day off, show a time report/balance, or fix an entry in the worktime log. Triggers: work time, time tracking, log hours, clock in, clock out, day off, time report, worktime."
disable-model-invocation: true
---

# timesamurai

`timesamurai` is a command-line worktime tracker. It keeps a JSONL log per
host (new entries are appended; `modify`/`delete` rewrite the file) and can
print accounting reports against a weekly hours target. The binary is on the
PATH as `timesamurai`.

Data lives in `~/git/worktime/timesamuraidb/`:

- `db.<host>.jsonl` — one JSON entry per line (the log). Never edit by hand.
- `undo.<host>.jsonl` — pending undo records, one per recent
  insert/modify/delete (consumed records are dropped).

Each entry has: `id`, `action` (`login`, `logout`, or `add`), `epoch`
(unix seconds), `host`, `value` (signed seconds; **0** for login/logout,
which omit the key on disk), `tags`, `descr` (empty fields are omitted on
disk). Worked time is computed by the report from
`logout epoch − login epoch`; `add` entries carry the seconds directly.

## The five commands you will use 90% of the time

```bash
timesamurai work start              # clock in (opens a session, tag "work")
timesamurai work stop               # clock out (closes the session)
timesamurai work status             # is there an open session?
timesamurai work report week        # this week's accounting report
timesamurai work add 1h -d "what it was"   # credit a fixed duration
```

## Decision guide

| The user wants to... | Run |
|---|---|
| Clock in / start work | `timesamurai work start` |
| Clock out / stop work | `timesamurai work stop` |
| See open sessions | `timesamurai work status` |
| Credit hours ("I worked 2h on X") | `timesamurai work add 2h -d "X"` |
| Take time back ("undo that 30m", "deduct 1h") | `timesamurai work sub 1h` |
| Log a lunch break | `timesamurai work add 1h lunch` |
| Record a full day off | `timesamurai work day-off` (no duration; 8h against "off", timestamped at midnight) |
| Move selfdevelopment buffer hours into work | `timesamurai work usebuffer 2h` |
| See hours for today / this week / a month | `timesamurai work report today` / `week` / `month` |
| See the full accounting report | `timesamurai work report` (no range) |
| Find entries matching text | `timesamurai work search "podcast"` |
| List entries by filter | `timesamurai work list --tag work --limit 20` |
| Change an entry's time/tags/descr | `timesamurai work modify <host:id> --...` (see [entries](references/entries.md)) |
| Remove an entry | `timesamurai work delete <host:id>` (try `--dry-run` first) |
| Revert the last change made from this machine | `timesamurai work undo` |
| Edit entries interactively | `timesamurai work edit [range]` (opens $EDITOR) |
| Record for another machine | add `--host <name>` (entry-creating commands only: `start`/`stop`/`add`/`sub`/`day-off`/`usebuffer`/`import`) |

## Reference Files

Load the one that matches the task:

- [Sessions and durations](references/sessions-durations.md) — `start` / `stop` / `status` sessions, and crediting or deducting fixed durations with `add` / `sub` / `usebuffer`
- [Reports](references/reports.md) — `report` ranges (today, week, month, full accounting) and how to read the output
- [Finding and changing entries](references/entries.md) — `list` and `search` filters, then `modify` / `delete` / `undo` / `edit` on a `host:id`
- [Time formats, tags and accounting](references/formats-tags.md) — what `--at`, `--since` and `--until` accept, and how tags drive the accounting
- [Hosts, storage, config, experiments and legacy import/export](references/storage-config.md) — per-host files and `--host`, config, trying things safely, and the legacy import/export (only when asked)

## Gotchas

- Bare integers: in durations = **seconds**; in `--at` = **unix epoch**.
- `login`/`logout` entries have `value` 0 — their hours only appear in
  reports. Don't "fix" them by adding a value.
- `week` = current ISO week starting Monday, not a rolling 7-day window.
- `modify --tags` replaces all tags; include the tags you want to keep.
- Plain `undo` reverts one change, only from this machine, in LIFO order.
- To move a clock-in/clock-out, `modify <host:id> --at 10:30`. Passing
  `--value` on a login/logout entry is rejected.
- A report may print warnings without failing, e.g.
  `warning: skipped host:id (logout without a matching login) at epoch N`
  (after a deleted or inconsistent entry) or `warning: superseded login
  discarded (never logged out): …`. Those are warnings, not failures.
- Never hand-edit the JSONL files; use modify/delete/edit/undo.
- When in doubt about a flag: `timesamurai work <cmd> --help` is
  authoritative. `-v/--verbose` on any `work` command prints full entry
  details instead of a one-line confirmation.
