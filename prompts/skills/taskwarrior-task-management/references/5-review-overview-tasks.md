# Review / overview tasks

Use with `00-context.md`. Project name and global rules apply.

## List tasks for the project

Only list tasks that have `+agent` (project + tag matching). When listing, order by **priority first, then urgency**:

```bash
ask list sort:priority-,urgency-
```

By tag (keep `+agent`, same order):

```bash
ask +<tag> list sort:priority-,urgency-
```

## Picking what to work on (next task)

**Order by priority first, then by urgency.** When choosing among tasks, always consider priority first (e.g. H then M then L), then urgency as a tiebreaker.

**Check already-started tasks first.** Before suggesting or starting a new task:

```bash
ask start.any: list sort:priority-,urgency-
```

- If any tasks are already started, **use one of those** (pick by priority, then urgency) — do not start a second task unless the user explicitly asks.
- Only if no tasks are in progress, show the next actionable (READY) task, ordered by priority then urgency:

```bash
ask +READY list sort:priority-,urgency- limit:1
```

(Or use `next limit:1` with a report that sorts priority first, then urgency, if your Taskwarrior config supports it.)

Once you have chosen a task from one of these lists, **immediately resolve its UUID** and use that for all subsequent operations and handoffs:

```bash
ask <id> _uuid
# or, for a filtered selection:
ask +READY limit:1 uuids
```

When returning or recording the chosen task for another agent or a later step, **include its UUID**, and in follow-up commands prefer a UUID selector (for example, `ask uuid:<uuid> ...`) instead of relying on the numeric ID from a previous report.

## View task details

```bash
ask <id>
# or, when you already have the UUID:
ask uuid:<uuid>
```

Only work with task IDs that came from the filtered lists above (project + `+agent`). Always read description, summary, and **all annotations** when working on or reviewing a task.

## Visualization

Dependency tree (export, agent tasks only):

```bash
ask export
```

Blocked vs ready (with `+agent`):

```bash
ask +BLOCKED list
ask +READY list
```

## Conventions

- When picking the next task: first list already-started (`start.any:`); if any exist, continue one of those; only if none, pick from `+READY`. **Always order by priority first, then urgency** (e.g. `sort:priority-,urgency-`).
- Among ready or started tasks, choose by priority (H then M then L), then by urgency.
