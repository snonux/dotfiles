# Review / overview tasks

Use with `00-context.md`. Project name and global rules apply.

## List tasks for the project

```bash
task project:<name> list
```

By tag:

```bash
task project:<name> +<tag> list
```

## Picking what to work on (next task)

**Check already-started tasks first.** Before suggesting or starting a new task:

```bash
task project:<name> start.any: list
```

- If any tasks are already started, **use one of those** — do not start a second task unless the user explicitly asks.
- Only if no tasks are in progress, show the next actionable (READY) task:

```bash
task project:<name> +READY next limit:1
```

## View task details

```bash
task <id>
```

Always read description, summary, and **all annotations** when working on or reviewing a task.

## Visualization

Dependency tree (export):

```bash
task project:<name> export
```

Blocked vs ready:

```bash
task project:<name> +BLOCKED list
task project:<name> +READY list
```

## Conventions

- When picking the next task: first list already-started (`start.any:`); if any exist, continue one of those; only if none, pick from `+READY` by urgency.
- Prefer `+READY` (unblocked) tasks sorted by urgency when choosing among ready tasks.
