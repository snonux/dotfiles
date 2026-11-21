---
name: work-on-tasks
description: "Automatically complete started and ready tasks for the current Git project using agent-task-management. Use when explicitly invoked as work-on-tasks, with optional selection strategy, task limit, and concurrency constraints."
disable-model-invocation: true
---

# Work on Tasks

Run only when explicitly requested. Work through the **current git
project's** tasks, one after another, until none is left that you can do.

## Parameters

- strategy (optional): how to choose among ready tasks: `highest-impact`
  (default), `priority`, `due-date`, `quick-win`.
- max_tasks (optional): stop after this many completed tasks.
- review (optional): `each` (default: one reviewer per task), `batch` (one
  review per milestone or ten tasks), or `none`. `batch` and `none` only when
  the user asks.

A concurrency limit stated with the parameters ("at most 2 agents",
"sequentially") always wins over the parallel default.

**Examples:** `$work-on-tasks`, `$work-on-tasks highest-impact`,
`$work-on-tasks priority 5`, `$work-on-tasks review=batch`

## What to do

Read [card-orchestrator.md](../agent-task-management/references/card-orchestrator.md)
and follow its nine steps. It is the whole loop. Paste
[card-worker.md](../agent-task-management/references/card-worker.md) into each
worker's prompt and
[card-reviewer.md](../agent-task-management/references/card-reviewer.md) into
each reviewer's. Do not load other references unless the card's "read more
only when" list applies.

This skill adds only the following.

**Choosing tasks.** Started tasks first, always. Among ready tasks, apply the
strategy; between equal tasks, prefer the one that unblocks others. The
`ask ready` listing is enough to choose; read a task in full only when you or
its worker start on it. Do not ask the user to pick unless there is real
ambiguity or risk.

**Keep going.** Never stop because one task is blocked. Park it
(`ask park <id> "<question>"`) and take the next. Stop only when:

- every remaining task is parked or waits on a parked one, or
- `max_tasks` is reached (launch nothing beyond it; let running workers
  finish), or
- the user says stop.

**Close each task when it is done.** Do not hold finished tasks for one big
merge or review at the end, except in `review=batch` mode, where tasks close
after self-review and checks and the batch review files new tasks.

**Stay in scope.** Work only on this project. Things you discover outside a
task's scope become new tasks.

**Final report.**

- completed task IDs and titles
- parked tasks with their questions (`ask parked`)
- worktrees or branches left for the user, and anything unpushed
- what remains pending
