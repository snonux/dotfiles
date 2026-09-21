# /work-on-tasks

**Description:** Automatically work through tasks for the current git project using the `agent-task-management` skill. The command selects pending tasks, executes them (delegating to a fresh sub-agent per task when there are 2+ tasks to work on, or implementing directly when there is only 1), completes them, and auto-progresses until no actionable tasks remain. Independent tasks may run as parallel sub-agents with no fixed cap, guarded by a memory check before each launch, unless an explicit concurrency limit is stated.

**Parameters:**
- strategy (optional): How to choose tasks when multiple are available (e.g., "highest-impact", "priority", "due-date", "quick-win")
- max_tasks (optional): Safety limit for how many tasks to process in one run

Any concurrency limit stated alongside the parameters (e.g. "at most 2 agents", "sequentially") is honored and overrides the parallel default.

**Example usage:**
- `/work-on-tasks`
- `/work-on-tasks highest-impact`
- `/work-on-tasks priority 5`

---

## Prompt

Use the `agent-task-management` skill for this entire workflow.

I want you to automatically execute tasks to work for the **current git project** from start to finish. Once one task completes, automatically continue with the next task.

### Your role: orchestrator (with a sub-agent threshold)

You are the **orchestrator**. You pick tasks, mark them started, launch sub-agents to do the implementation, then mark them done — **but only when there is enough work to justify the overhead of fresh contexts.**

**Sub-agent threshold:** At the start of each loop iteration, run `ask list start.any:` and count **all** tasks you would work on now: every already-started task (resume all of them first) plus the new tasks you would pick from `ask ready`. Recalculate after every completed task; do not reuse the previous iteration's mode:

- **Exactly one task to work on in total (one started and none ready, or none started and one ready) → work directly.** Do **not** spawn a sub-agent. Implement or resume the task yourself in the orchestrator's own context, running `ask start <id>` only when needed, doing the work, committing, and `ask done <id>` inline. The fresh-context overhead is not worth it for a single task, and staying in one context avoids re-loading project context.
- **2 or more tasks to work on (started and/or ready) → delegate per task.** Spawn one sub-agent per task, in parallel where the parallelism rules below allow it. This keeps your context small and lets each task run with a clean slate.

Whatever mode you are in, you still pick tasks, mark them started/done, commit, and auto-progress.

**Parallelism and memory guard:** The canonical rules live in the `agent-task-management` skill, `references/7-orchestrating-task-batches.md` (see also `2-start-task.md` and `3-complete-task.md`); follow them rather than any copy here. In short:

- **No fixed cap.** Run as many parallel tasks and sub-agents (implementation, fixing, and review) as is useful. **An explicit limit always wins:** if the user, this command's invocation, or a task states one ("at most 2 agents", "one at a time", "sequentially"), honor it exactly. The `strategy` and `max_tasks` parameters still apply.
- **Several tasks may be started at once** (one per worker). Multiple started tasks are a normal state, not an error.
- **Do not parallelize conflicting tasks.** Serialize tasks with dependencies, overlapping files/area, or a shared resource (port, database, build directory). If they must overlap, isolate each in its own git worktree (Agent `isolation: "worktree"`). With a shared worktree, each worker stages and commits **only its own files by explicit path** — never `git add -A`, `git add .`, or `git commit -a`.
- **Memory guard.** Before launching each sub-agent, and again whenever a worker finishes and a slot could be refilled, check available memory (`MemAvailable` floor, share of `MemTotal`, swap use, optionally load average) using the thresholds defined in reference 7. Launch in small waves (one or two workers, let them warm up, re-measure). On memory pressure, stop launching and let running workers finish; if nothing is running and memory is still low, work directly in your own context, one task at a time. Never kill user processes.
- **The orchestrator owns all launches, reviews, and worker accounting.** Instruct every task sub-agent (implementation, fixing, review) not to spawn nested sub-agents; it must return to the orchestrator for the next implementation or review step.

### Loop: repeat until no actionable tasks remain

1. **Load project-scoped tasks**:
   - Detect the current project from local git context (`git rev-parse --show-toplevel`)
   - Run `ask list start.any:` first. **Resume all already-started tasks before selecting anything new** — in parallel (subject to the conflict rules and memory guard), following the stalled-task recovery guidance in the skill (`6-recover-stalled-task.md`) before editing each one. Do not stop or ask because several tasks are started
   - Then run `ask ready | head` to list actionable tasks for the remaining free worker slots
   - Ignore completed/deleted tasks and non-actionable blocked items
   - Count the started plus newly selectable tasks to determine the sub-agent threshold above (exactly 1 → work directly; 2+ → delegate per task)

2. **Pick the next task(s)** (default strategy: `{{strategy|highest-impact}}`):
   - Started tasks are resumed first; then choose new actionable tasks from `ask ready` based on impact, urgency, and clarity, as many as can safely run in parallel
   - Skip ready tasks that conflict with a started or running one (dependencies, same files/area, shared resource); they wait or run in an isolated worktree
   - If two tasks are equivalent, prefer the one that unblocks other work
   - Run `ask info <id> 2>&1 | head -20` to preview each task — this caps the output at 20 lines so long descriptions do not flood the screen

3. **Mark each task started**:
   - Run `ask start <id>` for each selected task as its worker begins, unless the task is already started

4. **Execute the task(s)** (mode depends on the threshold decided in step 1):

   **If working directly (exactly one task to work on, ready or already started):**
   - Implement the task yourself in the orchestrator's own context.
   - Run `ask info <id>` to load the full description and annotations.
   - Run `ask annotate <id> "<progress notes>"` as you work.
   - Complete all implementation, tests, and a git commit.
   - Then proceed to step 5 (you mark the task done yourself).

   **If delegating (2+ tasks to work on):**
   - Spawn **one new sub-agent per task** (several at once are fine, within the parallelism rules and memory guard above), each with a self-contained prompt that includes:
     - The task ID and a one-line summary of what the task is about
     - Instruction to run `ask info <id>` as its **first action** to get the full description and all annotations (do not paste the description inline — the sub-agent fetches it fresh, keeping the prompt short)
     - The absolute path of the project root
     - Instruction to run `ask annotate <id> "<progress notes>"` as it works
     - Instruction to commit its in-scope changes to git when done, staging **only its own files by explicit path** (siblings may share the worktree; never `git add -A`, `git add .`, or `git commit -a`), unless it runs in its own worktree
     - Instruction to **not** mark the task done (the orchestrator does that)
     - Instruction to **not spawn other sub-agents**; the orchestrator owns the review cycle
   - Run the memory guard before each launch and launch in small waves; do not launch a worker for a task that conflicts with a running one (serialize it, or give it its own worktree)
   - Each sub-agent must complete all implementation, tests, and a git commit before returning
   - Wait for workers to finish; as each one returns, re-check memory and refill the free slot from the remaining started/ready tasks, then handle that worker in step 5 while the others keep running

5. **Review, close, and record** (per task, as each worker returns):
   - Perform the self-review required by `agent-task-management`, then launch a fresh expert review sub-agent. Instruct the reviewer not to spawn other sub-agents.
   - The reviewer must check the implementation, test coverage, real behavior assertions, and plausible negative tests, and report every concrete issue.
   - Address every finding. In direct mode, fix it directly. In delegated mode, launch a fresh fixing sub-agent after the reviewer finishes; instruct it not to mark the task done or spawn other sub-agents.
   - If a review reports any findings, resolve them, repeat self-review, and launch another fresh review sub-agent whether or not the resolution changed files. Continue until a review reports no remaining issues.
   - Ensure all final changes are committed before closing the task.
   - Run `ask done <id>` to mark the task complete
   - Run `ask annotate <id> "<summary of what was delivered>"` if the sub-agent did not already add a final annotation

6. **Auto-progress**:
   - After each task is closed, immediately return to step 1: re-run `ask list start.any:` (resume any started task without a live worker), then select new tasks from `ask ready` for the free slots
   - Stop when:
     - no actionable project tasks remain and no worker is still running, or
     - `{{max_tasks}}` tasks have been completed (if provided; do not launch more than would exceed it, let running workers finish), or
     - a sub-agent reports a hard blocker (surface it to the user, let the other running workers finish and be closed out, then stop)

7. **Final report**:
   - List completed task IDs/titles
   - List any skipped/blocked tasks with reasons
   - State what remains pending for the project

### Why sub-agents per task (when delegating)?

When there are 2+ tasks, each task runs in a **fresh context** with no carry-over from prior tasks. This:
- Prevents context drift (e.g. hallucinated paths) that accumulates over long sessions
- Matches the `agent-task-management` skill requirement: "Work on each new task must begin with a fresh context"
- Keeps the orchestrator's context minimal throughout the entire run
- Lets independent tasks run in parallel

For a single task the fresh-context overhead is not worth it — the orchestrator implements it directly. The `agent-task-management` "fresh context" requirement is satisfied by compaction / a new session when spawning a sub-agent is not warranted.

### Important behavior requirements

- Do not ask the user to pick a task unless there is a true ambiguity or risk.
- Default to autonomous execution.
- Keep task scope tied to the current project.
- There is no fixed sub-agent cap, but an explicit limit from the user, the invocation, or a task always wins; honor it exactly.
- Always run the memory guard (see `agent-task-management` `references/7-orchestrating-task-batches.md`) before launching any implementation, fixing, or review sub-agent, and again when a worker finishes. On memory pressure stop launching and let running workers finish; never kill user processes.
- Never run conflicting tasks (dependencies, overlapping files/area, shared resource) in the same worktree at the same time; serialize them or isolate them in separate worktrees. With a shared worktree, stage and commit only in-scope files by explicit path.
- Never allow task implementation, fixing, or review sub-agents to spawn nested sub-agents; the orchestrator owns all launches.
- Never implement tasks in the orchestrator's own context **when delegating** (2+ tasks to work on) — always delegate to a sub-agent. When there is exactly 1 task to work on, implement directly instead of spawning a sub-agent.
- Resume all already-started tasks before selecting new ones from `ask ready`; several started tasks are normal, never a reason to stop.
- After a task's implementation, review, fixes, and closure are complete, immediately move on (refill free worker slots, or pick the next task).
