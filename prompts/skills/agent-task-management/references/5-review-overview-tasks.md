# Review / overview tasks

Use with `00-cli.md` and `00-project-scope.md`.

## List tasks for the project

Only list tasks that have `+agent` (project + tag matching). When listing, order by **priority first, then urgency**:

```bash
ask list sort:priority-,urgency-
```

By tag (keep `+agent`, same order):

```bash
ask list +<tag> sort:priority-,urgency-
```

## Time-range queries (completed tasks)

`ask completed` supports `since:` for "completed over the last …" queries, plus raw taskwarrior date-attribute filters:

```bash
ask completed since:today
ask completed since:24.hours
ask completed since:7.days
ask completed since:this.week
ask completed since:2.months
ask completed end:today            # raw taskwarrior pass-through
ask completed end.after:2026-08-22 # absolute boundary
```

Do not rely on raw taskwarrior relative date values (e.g. `end:7.days`, `end:7.days.ago`) — they are unreliable in taskwarrior 2.x filters. Use `since:` instead.

## Picking what to work on (next task)

**Order by priority first, then by urgency.** When choosing among tasks, always consider priority first (e.g. H then M then L), then urgency as a tiebreaker.

**Check already-started tasks first.** Before suggesting or starting a new task:

```bash
ask list start.any: sort:priority-,urgency-
```

- **Resume all started tasks** before starting anything new. Several started tasks are normal (one per parallel worker); see [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md) for the parallelism policy and memory guard.
- Then show the next actionable (READY) tasks for any free worker slots, ordered by priority then urgency, skipping tasks that conflict with started ones:

```bash
ask ready
```

Once you have chosen a task from one of these lists, **use its alias ID** from the list output for all subsequent operations and handoffs. When returning or recording the chosen task for another agent or a later step, **include its alias ID**.

## View task details

```bash
ask info <id>
```

Always read description, summary, and **all annotations** when working on or reviewing a task.

## Visualization

Dependency tree (all agent tasks):

```bash
ask list
```

Blocked vs ready (with `+agent`):

```bash
ask list +BLOCKED sort:priority-,urgency-
ask ready
```

## Conventions

- When picking the next task: first list already-started (`start.any:`) and resume all of them; then pick from `+READY` for any free worker slots. **Always order by priority first, then urgency** (e.g. `sort:priority-,urgency-`).
- Among ready or started tasks, choose by priority (H then M then L), then by urgency.
- When returning a chosen task to the user or another agent, include its alias ID and description.
