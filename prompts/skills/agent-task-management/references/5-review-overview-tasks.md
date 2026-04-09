# Review / overview tasks

Use with `00-context.md`. Project name and global rules apply.

## List tasks for the project

Only list tasks that have `+agent` (project + tag matching). When listing, order by **priority first, then urgency**:

```bash
~/go/bin/do list sort:priority-,urgency-
```

By tag (keep `+agent`, same order):

```bash
~/go/bin/do list +<tag> sort:priority-,urgency-
```

## Picking what to work on (next task)

**Order by priority first, then by urgency.** When choosing among tasks, always consider priority first (e.g. H then M then L), then urgency as a tiebreaker.

**Check already-started tasks first.** Before suggesting or starting a new task:

```bash
~/go/bin/do list start.any: sort:priority-,urgency-
```

- If any tasks are already started, **use one of those** (pick by priority, then urgency) — do not start a second task unless the user explicitly asks.
- Only if no tasks are in progress, show the next actionable (READY) task, ordered by priority then urgency:

```bash
~/go/bin/do ready
```

Once you have chosen a task from one of these lists, **use its alias ID** from the list output for all subsequent operations and handoffs. When returning or recording the chosen task for another agent or a later step, **include its alias ID**.

## View task details

```bash
~/go/bin/do info <id>
```

Always read description, summary, and **all annotations** when working on or reviewing a task.

## Visualization

Dependency tree (all agent tasks):

```bash
~/go/bin/do list
```

Blocked vs ready (with `+agent`):

```bash
~/go/bin/do list +BLOCKED sort:priority-,urgency-
~/go/bin/do ready
```

## Conventions

- When picking the next task: first list already-started (`start.any:`); if any exist, continue one of those; only if none, pick from `+READY`. **Always order by priority first, then urgency** (e.g. `sort:priority-,urgency-`).
- Among ready or started tasks, choose by priority (H then M then L), then by urgency.
- When returning a chosen task to the user or another agent, include its alias ID and description.
