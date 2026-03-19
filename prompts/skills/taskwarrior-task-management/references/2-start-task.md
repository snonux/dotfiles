# Start task

Use with `00-context.md`. Project name and global rules apply (including one task in progress per project unless the user says otherwise). Only start tasks that have both `project:<name>` and the `+agent` tag — use task IDs from `project:<name> +agent` filtered lists.

## Start each new task with a fresh context

Work on each new task **must begin with a fresh context** — e.g. a new session or a sub-agent with no prior conversation. That way the task is executed with clear focus and no carry-over from other work. The task itself should already contain references to all required context (added when the task was created); read the task description and all annotations to get files, docs, and specs before starting.

## Mark task as started

When you begin working on a task, **always mark it as started in Taskwarrior** so current work is visible:

```bash
ask uuid:<uuid> start
```

Do this as soon as you start work on the task.

## Conventions

- Start each new task with a fresh context; rely on the task’s description and annotations for all required context.
- Run `ask uuid:<uuid> start` when you start working on the task, not only when listing or completing.
- Do not start a second task for the same project while one is already started and not done, unless the user explicitly asks.
- When a task is selected via the review/overview step, use the stored UUID (for example, `uuid:<uuid>`) for subsequent `start` operations, not a freshly-looked-up numeric ID from a new report.
