---
name: agent-task-management
description: "Manage agent tasks scoped to the current git project using the `~/go/bin/ask` CLI. Use when asked to list, add, start, complete, annotate, or organize tasks for the project. Prefer compaction over starting a new context when beginning a new task. May start work in parallel (e.g. multiple sub-agents on different tasks) as long as agents do not conflict with each other. Triggers on: tasks, todo, task list, pick next task, what's next."
---

# Agent Task Management

Tasks are scoped to the current git repository via the `~/go/bin/ask` CLI. **Load only the files you need** for the current action so the whole skill does not need to be in context.

The task CLI at `~/go/bin/ask` provides subcommands (`list`, `ready`, `add`, `info`, `start`, `stop`, `done`, `annotate`, `modify`, `tag`, `priority`, `dep`, `delete`, `urgency`) that operate on agent-managed tasks in the current project. It is not a natural-language interface and does not understand skill names. Use normal subcommand syntax only.

Valid examples:

- `~/go/bin/ask list`
- `~/go/bin/ask ready`
- `~/go/bin/ask add +cli "Add feature X"`  # prints `created task <alias-id>`
- `~/go/bin/ask add +cli depends:0,1 "Add feature X"`
- `~/go/bin/ask info <id>`
- `~/go/bin/ask start <id>`
- `~/go/bin/ask annotate <id> "progress note"`
- `~/go/bin/ask done <id>`

Invalid examples:

- `~/go/bin/ask agent-task-management ...`
- `~/go/bin/ask list tasks`
- `~/go/bin/ask show task 298`
- any other natural-language phrasing passed to `~/go/bin/ask`

**Alias IDs are the selectors to use for task work.** `~/go/bin/ask add` prints `created task <alias-id>`, and subsequent task commands in this workflow should keep using that alias ID throughout the workflow.

## Context and compaction

When beginning a new task, **always use a fresh context** — spawn a sub-agent (if orchestrating via `/work-on-tasks`) or start a new session. Do not carry implementation context from one task to the next; accumulated context causes drift (e.g. hallucinated paths) in long-running models. Compaction is a fallback only when spawning a sub-agent or new session is not possible.

## When to Use

- User asks to **list**, **add**, **start**, **complete**, **annotate**, or **organize** tasks for the project.
- Triggers: *tasks*, *todo*, *task list*, *pick next task*, *what's next*.
- You may start work **in parallel** (e.g. multiple sub-agents on different tasks) as long as agents do not conflict with each other.

## When to load what

| Action | Load |
|--------|------|
| **Create task** | `references/00-context.md` + `references/1-create-task.md` (include refs to all context required) |
| **Start task** | `references/00-context.md` + `references/2-start-task.md` (start with fresh context; use task refs) |
| **Complete task** | `references/00-context.md` + `references/3-complete-task.md` |
| **Annotate / update task** | `references/00-context.md` + `references/4-annotate-update-task.md` |
| **Review / overview tasks** | `references/00-context.md` + `references/5-review-overview-tasks.md` |

Always load `references/00-context.md` first (project name resolution and global rules); then load the one action file that matches what you are doing.

## Task lifecycle (overview)

1. Create task → 2. Start task → 3. Annotate as you go → 4. **Completion criteria** (best practices, compilable, all tests pass, negative tests where plausible) → 5. Sub-agent review (fresh context) → 6. Main agent addresses all review comments → 7. **Repeat sub-agent review + fixes until no issues are found** → 8. **Commit all changes to git** → 9. Complete task → 10. **Automatically progress to the next task in the list** (when all tests and required sub-agent review(s) pass).

A task is not done until criteria are met, all review comments are addressed, **and the sub-agent review cycle has completed with no remaining issues**, and all changes are committed to git. After completing a task, start the next task in the list (if any). Details are in `references/3-complete-task.md`.
