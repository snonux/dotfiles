---
name: agent-task-management
description: "Manage agent tasks scoped to the current git project using the `ask` CLI. Use when asked to list, add, start, complete, annotate, or organize tasks for the project. Triggers on: tasks, todo, task list, pick next task, what's next."
---

# Agent Task Management

`ask` is a CLI with fixed subcommands, never free text. Start with the card
for your role. Each card is under 200 words and is usually all you need; it
ends with the few cases that need another file.

| Your role | Read |
|---|---|
| Implement one task | [card-worker.md](references/card-worker.md) |
| Review a finished task | [card-reviewer.md](references/card-reviewer.md) |
| Run several tasks, or keep going until none is left | [card-orchestrator.md](references/card-orchestrator.md) |

Orchestrators paste the worker or reviewer card into the sub-agent's prompt,
so sub-agents do not need to load this skill.

## Read these only when the situation applies

| Situation | Read |
|---|---|
| Unsure about an `ask` command or filter | [00-cli.md](references/00-cli.md) |
| A task is missing, or you work in a subdirectory or another project | [00-project-scope.md](references/00-project-scope.md) |
| Creating tasks | [1-create-task.md](references/1-create-task.md) |
| Closing a code-audit batch outside auditing-code-quality | [1a-audit-task-batches.md](references/1a-audit-task-batches.md) |
| A worker-card rule is unclear (scope, red first, glossary) | [2-start-task.md](references/2-start-task.md) |
| Completion criteria, commit message template | [3-complete-task.md](references/3-complete-task.md) |
| Reviewer edge cases | [3b-review-checklist.md](references/3b-review-checklist.md) |
| The tree was dirty before the task, or workers share a tree | [3c-commit-in-scope.md](references/3c-commit-in-scope.md) |
| Reviews do not converge; batch reviews; no reviews | [3d-review-budget.md](references/3d-review-budget.md) |
| Annotation prefixes; modifying or deleting tasks | [4-annotate-update-task.md](references/4-annotate-update-task.md) |
| Listing tasks, completed-task queries | [5-list-tasks.md](references/5-list-tasks.md) |
| Resuming a task someone else started | [6-recover-stalled-task.md](references/6-recover-stalled-task.md) |
| Parallelism, conflicts, memory guard, worker prompt | [7-orchestrating-task-batches.md](references/7-orchestrating-task-batches.md) |
| Cloud workers; worktree cleanup | [7b-cloud-workers-and-worktrees.md](references/7b-cloud-workers-and-worktrees.md) |
| Blocked task, a question for the user, stopping unfinished | [8-blocked-and-handoff.md](references/8-blocked-and-handoff.md) |
| Reporting what was and was not verified | [verification-honesty.md](references/verification-honesty.md) |

Do not load a file "to be safe". Every word loaded is paid for by every
agent on every task. The manual [work-on-tasks skill](../work-on-tasks/SKILL.md)
drives the orchestrator card with a strategy and a task limit.
