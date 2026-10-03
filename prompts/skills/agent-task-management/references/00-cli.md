# `ask` CLI contract

`ask` is a CLI with fixed subcommands, not a natural-language interface. The
skill name is never an `ask` subcommand. Do not run `ask agent-task-management
…`, `ask <free text>`, or any other unsupported phrase.

The only valid form is `ask <subcommand> [args]`. The subcommands are:

`list`, `all`, `ready`, `completed`, `add`, `info`, `start`, `stop`, `done`,
`annotate`, `denotate`, `modify`, `edit`, `tag`, `priority`, `dep`, `delete`,
`urgency`, `projects`, `watch`, `fish`, `help`.

Examples:

```bash
ask list
ask ready
ask completed since:7.days
ask ready due-within:7.days
ask all +agent sort:priority-
ask add +cli "Add feature X"
ask add +cli depends:0,1 "Add feature X"
ask info <id>
ask start <id>
ask annotate <id> "progress note"
ask done <id>
```

For `list`, `all`, `ready`, and `completed`, supported filters include
`limit:<n>`, `sort:<key>`, `+<tag>`, `started`, `since:<value>`, and raw
Taskwarrior date-attribute filters. `since:` accepts `today`, `this.week`,
`this.month`, or `N.hours`, `N.days`, `N.weeks`, or `N.months`; `ask` resolves
it to an absolute `end.after:` boundary because Taskwarrior 2.x relative date
filters are unreliable.

To filter by due date, use `due-within:<value>` (due by the end of the period,
overdue included) or `due-window:<value>` (the same, plus tasks without a due
date), e.g. `ask ready due-window:7.days`. Both accept the same values as
`since:` (without `.ago`) and also work with `ask projects`.

Use the alias ID printed by `ask add` and shown by task listings for all
subsequent commands in that task workflow. Prefer `ask` so the correct binary
is used regardless of `PATH`; it is installed at `~/go/bin/ask`.
