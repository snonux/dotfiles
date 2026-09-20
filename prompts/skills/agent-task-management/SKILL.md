---
name: agent-task-management
description: "Manage agent tasks scoped to the current git project using the `ask` CLI. Use when asked to list, add, start, complete, annotate, or organize tasks for the project. Triggers on: tasks, todo, task list, pick next task, what's next."
---

# Agent Task Management

Use `ask` only through its fixed subcommands. Before executing any task command,
read [the CLI contract](references/00-cli.md). Then read the shared project
scope reference and only the action reference needed for the request.

| Action | Read |
|---|---|
| Any project-scoped task action | [00-project-scope.md](references/00-project-scope.md) |
| Create a task | [1-create-task.md](references/1-create-task.md) |
| Create audit finding tasks as the top-level non-ACQ orchestrator | [1a-audit-task-batches.md](references/1a-audit-task-batches.md), after `1-create-task.md` |
| Start a task | [2-start-task.md](references/2-start-task.md) |
| Recover a stalled or interrupted task | [6-recover-stalled-task.md](references/6-recover-stalled-task.md) and [verification-honesty.md](references/verification-honesty.md) |
| Complete a task | [3-complete-task.md](references/3-complete-task.md) and [verification-honesty.md](references/verification-honesty.md) |
| Annotate or update a task | [4-annotate-update-task.md](references/4-annotate-update-task.md) |
| Review or overview tasks | [5-review-overview-tasks.md](references/5-review-overview-tasks.md) |
| Orchestrate several tasks or `/work-on-tasks` | [7-orchestrating-task-batches.md](references/7-orchestrating-task-batches.md) plus the selected action references |

Read only the references that the requested action requires. Task descriptions
and annotations must contain the context a fresh worker needs; read them in full
before implementing a task.
