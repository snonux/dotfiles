# Start task

Use with `00-context.md`. Project name and global rules apply (including one task in progress per project unless the user says otherwise). 

## Start each new task with a fresh context

Work on each new task **must begin with a fresh context** — a new sub-agent with no prior conversation history. That way the task is executed with clear focus and no carry-over from other work.

**If you are orchestrating via `/work-on-tasks`:** spawn a sub-agent for the implementation. Pass the full task description, all annotations, and the project root path to the sub-agent. Do not implement tasks in the orchestrator's own context.

**If you are starting a single task manually:** begin in a new session or compact first so the context is clean before you start working.

The task itself should already contain references to all required context (added when the task was created); read the task description and all annotations to get files, docs, and specs before starting.

## Finding a task

```bash
ask ready | head
```

## Mark task as started

When you begin working on a task, **always mark it as started** so current work is visible:

```bash
ask start uuid:<uuid>
```

Do this as soon as you start work on the task.

## Conventions

- Start each new task with a fresh context; rely on the task's description and annotations for all required context.
- Run `ask start uuid:<uuid>` when you start working on the task, not only when listing or completing.
- Do not start a second task for the same project while one is already started and not done, unless the user explicitly asks.
- When a task is selected via the review/overview step, use the stored UUID from the task's annotations for subsequent `start` operations.
