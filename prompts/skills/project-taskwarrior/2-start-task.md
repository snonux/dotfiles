# Start task

Use with `00-context.md`. Project name and global rules apply (including one task in progress per project unless the user says otherwise).

## Mark task as started

When you begin working on a task, **always mark it as started in Taskwarrior** so current work is visible:

```bash
task <id> start
```

Do this as soon as you start work on the task.

## Conventions

- Run `task <id> start` when you start working on the task, not only when listing or completing.
- Do not start a second task for the same project while one is already started and not done, unless the user explicitly asks.
