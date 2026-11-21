---
name: work-on-tasks
description: "Automatically complete started and ready tasks for the current Git project using agent-task-management. Use when explicitly invoked as work-on-tasks, with optional selection strategy, task limit, and concurrency constraints."
disable-model-invocation: true
---

# Work on Tasks

Run only when explicitly requested. Execute the **current git project's**
tasks from start to finish, and once one task completes, continue with the next.

## Parameters

- strategy (optional): How to choose tasks when multiple are available (e.g., "highest-impact", "priority", "due-date", "quick-win")
- max_tasks (optional): Safety limit for how many tasks to process in one run

Any concurrency limit stated alongside the parameters (e.g. "at most 2 agents",
"sequentially") is honored and overrides the parallel default.

**Example usage:**
- `$work-on-tasks`
- `$work-on-tasks highest-impact`
- `$work-on-tasks priority 5`

## No sub-agent tool?

If your harness cannot spawn sub-agents (common with small local models), use
this short path and ignore everything below about workers and reference 7:

1. `ask list start.any:` and resume a started task; otherwise take the first
   task from `ask ready | head`.
2. Follow the "Short version" in [2-start-task.md](../agent-task-management/references/2-start-task.md).
3. Follow the "Short version" in [3-complete-task.md](../agent-task-management/references/3-complete-task.md),
   applying [3b-review-checklist.md](../agent-task-management/references/3b-review-checklist.md)
   to your own work in place of a reviewer.
4. Repeat from step 1 until no task is left or `max_tasks` is reached, then
   write the final report (step 8 of the loop below).

## Where the rules live

Read [agent-task-management](../agent-task-management/SKILL.md) directly and
use it for the whole run. This skill adds only the loop, its parameters, the
stop conditions, and the final report. Where a line below summarizes a rule,
the reference is authoritative:

- Selection, the sub-agent threshold, and proving a change ("Prove the change
  (red first)"): [2-start-task.md](../agent-task-management/references/2-start-task.md)
- Parallelism, conflict rules, memory guard, worker prompt, optional cloud
  workers, worktree cleanup: [7-orchestrating-task-batches.md](../agent-task-management/references/7-orchestrating-task-batches.md)
- Completion criteria, review budget, in-scope commits: [3-complete-task.md](../agent-task-management/references/3-complete-task.md)
- What a reviewer checks and reports: [3b-review-checklist.md](../agent-task-management/references/3b-review-checklist.md)
- Resuming stalled tasks: [6-recover-stalled-task.md](../agent-task-management/references/6-recover-stalled-task.md)

## Your role: orchestrator

You pick tasks, mark them started, run or delegate the work, run reviews, mark
tasks done, and keep going. **Complete every already-started task before
starting a new one**, unless this invocation says otherwise; several started
tasks are normal, never a reason to stop.

At the start of every iteration, count every task you would work on now:
all started tasks plus the ready ones you would pick. Recount after each
completed task.

- **Exactly one → work directly** in your own context. A fresh sub-agent is not
  worth the overhead for one task; compaction or a new session gives the fresh
  context instead.
- **Two or more → one worker per task**, in parallel where the conflict rules
  and memory guard allow. Do not implement these in your own context. Fresh
  workers avoid context drift between tasks and keep your context small.

Workers may be local sub-agents or, when available and suitable, cloud agents
("Cloud workers" in reference 7). Cloud workers are optional; follow your own
instructions about when to prefer them. Workers and reviewers never spawn
sub-agents; you own every launch.

## Loop: repeat until no actionable tasks remain

1. **Load tasks.** Detect the project (`git rev-parse --show-toplevel`). Run
   `ask list start.any:` and resume every started task first, following the
   stalled-task guidance. Then run `ask ready | head` for the free slots, and
   count tasks for the threshold above.
2. **Pick** (default strategy `highest-impact`, unless another was given):
   choose by impact, urgency, and clarity, as many as can run safely in
   parallel. Skip tasks that conflict with running ones. Between equivalent
   tasks, prefer the one that unblocks other work. Preview each with
   `ask info <id> 2>&1 | head -20`.
3. **Start** each selected task with `ask start <id>` as its worker begins,
   unless it is already started.
4. **Execute.**
   - *Direct:* run `ask info <id>` for the full task and annotate progress as
     you go. Prove the change as reference 2 describes. Make and verify one
     coherent change before widening scope. Finish with tests and a commit.
   - *Delegated:* launch one worker per task with the worker prompt from
     reference 7. Run the memory guard before each local launch and launch in
     small waves. As each worker returns, refill its slot from the remaining
     tasks and handle the returned task in step 5.
5. **Review and close** each task as it finishes: self-review, then a fresh
   reviewer given `3b-review-checklist.md`, under the review budget in reference 3 (at most two rounds, the
   second only for blocking findings). Fix blocking findings yourself in direct
   mode, or send them to the worker or a fresh fixer in delegated mode. Commit
   in-scope changes, run `ask done <id>`, and add a final annotation if the
   worker did not.
6. **Auto-progress:** return to step 1. Stop when:
   - no actionable tasks remain and no worker is running, or
   - `max_tasks` tasks are complete (launch nothing that would exceed it; let
     running workers finish), or
   - a worker reports a hard blocker (surface it, let the other workers finish
     and close out, then stop).
7. **Clean up** the run's worktrees and branches as "Worktree cleanup" in
   reference 7 describes.
8. **Final report:** completed task IDs and titles; skipped or blocked tasks
   with reasons; worktrees or branches left for the user; what remains pending.

## Behavior

- Default to autonomous execution. Ask the user to pick only when there is
  true ambiguity or risk.
- Keep work scoped to the current project. Out-of-scope discoveries become new
  tasks with full context.
- An explicit limit from the user, the invocation, or a task always wins.
- Close each task as soon as it meets its criteria; do not hold finished tasks
  for one big final merge. Then move on immediately.
