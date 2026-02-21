# Review / overview tasks

Use with `00-context.md`. Project name and global rules apply.

## List tasks for the project

Only list tasks that have `+agent` (project + tag matching). When listing, order by **priority first, then urgency**:

```bash
task project:<name> +agent list sort:priority-,urgency-
```

By tag (keep `+agent`, same order):

```bash
task project:<name> +agent +<tag> list sort:priority-,urgency-
```

## Picking what to work on (next task)

**Order by priority first, then by urgency.** When choosing among tasks, always consider priority first (e.g. H then M then L), then urgency as a tiebreaker.

**Check already-started tasks first.** Before suggesting or starting a new task:

```bash
task project:<name> +agent start.any: list sort:priority-,urgency-
```

- If any tasks are already started, **use one of those** (pick by priority, then urgency) — do not start a second task unless the user explicitly asks.
- Only if no tasks are in progress, show the next actionable (READY) task, ordered by priority then urgency:

```bash
task project:<name> +agent +READY list sort:priority-,urgency- limit:1
```

(Or use `next limit:1` with a report that sorts priority first, then urgency, if your Taskwarrior config supports it.)

## View task details

```bash
task <id>
```

Only work with task IDs that came from the filtered lists above (project + `+agent`). Always read description, summary, and **all annotations** when working on or reviewing a task.

## Visualization

Dependency tree (export, agent tasks only):

```bash
task project:<name> +agent export
```

Blocked vs ready (with `+agent`):

```bash
task project:<name> +agent +BLOCKED list
task project:<name> +agent +READY list
```

## Conventions

- When picking the next task: first list already-started (`start.any:`); if any exist, continue one of those; only if none, pick from `+READY`. **Always order by priority first, then urgency** (e.g. `sort:priority-,urgency-`).
- Among ready or started tasks, choose by priority (H then M then L), then by urgency.
