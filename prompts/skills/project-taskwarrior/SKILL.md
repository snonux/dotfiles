---
name: project-taskwarrior
description: "Manage Taskwarrior tasks scoped to the current git project. Use when asked to list, add, start, complete, annotate, or organize tasks for the project. May start work in parallel (e.g. multiple sub-agents on different tasks) as long as agents do not conflict with each other. Triggers on: tasks, todo, task list, pick next task, what's next."
---

# Project Taskwarrior

Taskwarrior tasks are scoped to the current git repository. **Load only the files you need** for the current action so the whole skill does not need to be in context.

## When to Use

- User asks to **list**, **add**, **start**, **complete**, **annotate**, or **organize** tasks for the project.
- Triggers: *tasks*, *todo*, *task list*, *pick next task*, *what's next*.
- You may start work **in parallel** (e.g. multiple sub-agents on different tasks) as long as agents do not conflict with each other.

## When to load what

| Action | Load |
|--------|------|
| **Create task** | `00-context.md` + `1-create-task.md` (include refs to all context required) |
| **Start task** | `00-context.md` + `2-start-task.md` (start with fresh context; use task refs) |
| **Complete task** | `00-context.md` + `3-complete-task.md` |
| **Annotate / update task** | `00-context.md` + `4-annotate-update-task.md` |
| **Review / overview tasks** | `00-context.md` + `5-review-overview-tasks.md` |

Always load `00-context.md` first (project name resolution and global rules); then load the one action file that matches what you are doing.

## Task lifecycle (overview)

1. Create task → 2. Start task → 3. Annotate as you go → 4. **Completion criteria** (best practices, compilable, all tests pass, negative tests where plausible) → 5. Sub-agent review (fresh context) → 6. Main agent addresses all review comments → 7. **Second sub-agent review** (fresh context again) to confirm fixes → 8. **Commit all changes to git** → 9. Complete task

A task is not done until criteria are met, all review comments are addressed, a second sub-agent review has confirmed the code, and all changes are committed to git. Details are in `3-complete-task.md`.
