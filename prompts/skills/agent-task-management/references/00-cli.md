# `ask` CLI contract

`ask` is a CLI with fixed subcommands, built to be driven by agents. It is not
a natural-language interface and not a skill runner.

Valid: `ask ready`, `ask info <id>`, `ask annotate <id> "note"`, `ask done <id>`.
Invalid: `ask agent-task-management ...`, `ask list tasks`, `ask show task 298`,
`ask tasks`, or any other free text. A single unknown word is refused; several
unknown words become a new task, so a mistyped command can create junk.

## Subcommands

| Do this | Command |
|---|---|
| Tasks already started | `ask list start.any:` |
| Tasks you can start now (parked ones are hidden) | `ask ready` |
| All pending tasks | `ask list` |
| Read a task in full (first time) | `ask info <id>` |
| Re-read a task you already know | `ask info <id> last:3` |
| Create a task | `ask add +<tag> "Description"` |
| Start / stop | `ask start <id>` / `ask stop <id> ["Handoff: ..."]` |
| Record a milestone | `ask annotate <id> "note"` |
| Finish, with a one-line summary | `ask done <id> ["summary"]` |
| Needs a human: stop, hide from ready, record the question | `ask park <id> "question"` |
| Open questions / release one | `ask parked` / `ask unpark <id>` |
| Change fields | `ask modify <id> priority:H`, `ask tag <id> +x`, `ask dep add <id> <dep>` |
| Finished tasks | `ask completed since:7.days` |

Others: `all`, `count`, `denotate`, `edit`, `priority`, `delete`, `urgency`,
`projects`, `watch`, `fish`, `help`. `ask help` prints the full list.

`ask info <id>` is the only way to show a task; its annotations are part of
the output. There is no `show`, `notes`, `annotations`, `task`, `get` or
`status` subcommand (ask redirects those to `info` and says so).

`last:<n>` shows only the newest n annotations and says how many it left out.
The optional note on `stop` and `done` is recorded as an annotation before the
state changes, so one call replaces two.

## Filters

For `list`, `all`, `ready`, and `completed`: `limit:<n>`, `sort:<key>`,
`+<tag>`, `started`, `since:<value>`, and raw Taskwarrior date-attribute
filters. `since:` accepts `today`, `this.week`, `this.month`, or `N.hours`,
`N.days`, `N.weeks`, `N.months`; `ask` resolves it to an absolute `end.after:`
boundary because Taskwarrior 2.x relative date filters are unreliable.

To filter by due date, use `due-within:<value>` (due by the end of the period,
overdue included) or `due-window:<value>` (the same, plus tasks without a due
date), e.g. `ask ready due-window:7.days`. Both accept the same values as
`since:` (without `.ago`) and also work with `ask projects`.

## IDs

Use the alias ID printed by `ask add` and shown by task listings for all
later commands. Numeric Taskwarrior IDs are not accepted. The binary is
installed at `~/go/bin/ask`.
