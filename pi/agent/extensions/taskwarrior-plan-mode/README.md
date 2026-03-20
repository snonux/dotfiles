# Taskwarrior Plan Mode

Custom Pi plan mode built on the official `plan-mode` example, but using
Taskwarrior as the actual task source of truth through the
`taskwarrior-task-management` workflow.

## What it changes

- `/plan` enters read-only planning mode
- `/plan-exit` leaves planning mode and restores normal tools
- blocks raw `task` and requires `ask ...`
- injects current project Taskwarrior context into planning turns
- extracts `Plan:` sections into actionable steps
- `/plan-create-tasks [sequential|independent]` turns the last extracted plan
  into real Taskwarrior tasks
- `/task-sync [sequential|independent]` remains as a legacy alias
- `/task-update <selector> :: <new description>` replaces a task description
- `/task-modify <selector> :: <mods>` runs raw `ask ... modify ...` arguments
- `/task-next [run]` focuses the started task, or starts the next `+READY` task
- `/tasks` shows the current started and READY tasks for the repo
- `/work-on-tasks [strategy] [max]` kicks off the project task loop using the
  Taskwarrior skill semantics

## Task semantics

This extension is aligned to the `taskwarrior-task-management` skill:

- `ask ...` only, never raw `task`
- project-scoped by current git repo
- continue started task first
- use UUIDs for stable references
- do not mark a task done until implementation, tests, and commit are complete
- self-review first, then run an independent fresh-context subagent review if
  the `subagent` tool is available

## Core workflow

1. Run `/plan`
2. Ask Pi to analyze the repo and produce a numbered `Plan:`
3. After the plan is extracted, run `/plan-create-tasks sequential`
4. If needed, adjust tasks with `/task-update` or `/task-modify`
5. Run `/plan-exit`

Planning mode is intentionally read-only. The extension no longer auto-prompts
you to create tasks after planning; task creation is explicit.

The extracted plan is session-local. Use `/plan`, your planning prompt,
`/plan-create-tasks`, and `/plan-exit` within the same interactive or continued
Pi session.

## Examples

Create tasks from the last plan:

```text
/plan-create-tasks sequential
```

Rewrite a task description:

```text
/task-update uuid:12345678-1234-1234-1234-123456789abc :: Restore SSH host verification during bootstrap
```

Apply raw Taskwarrior modify arguments:

```text
/task-modify uuid:12345678-1234-1234-1234-123456789abc :: priority:H +security
```

In-place description replacement with Taskwarrior syntax:

```text
/task-modify uuid:12345678-1234-1234-1234-123456789abc :: /bootstrap/provisioning/
```

## Notes

- Planning mode is read-only by design.
- All Taskwarrior operations still go through `ask`, never raw `task`.
- Execution mode injects the current Taskwarrior task back into the agent prompt
  so the model works against the real task rather than an in-memory checklist.
