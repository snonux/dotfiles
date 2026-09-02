# /work-on-tasks

**Description:** Automatically work through tasks for the current git project using the `agent-task-management` skill. The command selects pending tasks, executes them (delegating to a fresh sub-agent when there are 2+ open tasks, or implementing directly when there is only 1), completes them, and auto-progresses until no actionable tasks remain, with a per-orchestrator limit of 3 concurrent sub-agents.

**Parameters:**
- strategy (optional): How to choose tasks when multiple are available (e.g., "highest-impact", "priority", "due-date", "quick-win")
- max_tasks (optional): Safety limit for how many tasks to process in one run

**Example usage:**
- `/work-on-tasks`
- `/work-on-tasks highest-impact`
- `/work-on-tasks priority 5`

---

## Prompt

Use the `agent-task-management` skill for this entire workflow.

I want you to automatically execute tasks to work for the **current git project** from start to finish. Once one task completes, automatically continue with the next task.

### Your role: orchestrator (with a sub-agent threshold)

You are the **orchestrator**. You pick tasks, mark them started, launch a sub-agent to do the implementation, then mark them done — **but only when there is enough work to justify the overhead of fresh contexts.**

**Sub-agent threshold:** At the start of each loop iteration, check for an already-started task first. Resume it directly if one exists. Otherwise count the actionable tasks from `ask ready` and choose the mode for that task. Recalculate after every completed task; do not reuse the previous iteration's mode:

- **One ready task, or an already-started task → work directly.** Do **not** spawn a sub-agent. Implement or resume the task yourself in the orchestrator's own context, running `ask start <id>` only when needed, doing the work, committing, and `ask done <id>` inline. The fresh-context overhead is not worth it for a single task, and staying in one context avoids re-loading project context.
- **2 or more open tasks → delegate per task.** Use the sub-agent-per-task flow described below. This keeps your context small and lets each task run with a clean slate.

Whatever mode you are in, you still pick tasks, mark them started/done, commit, and auto-progress.

**Concurrency limit:** Never have more than **3 sub-agents running at the same time**. This limit covers every implementation and review sub-agent launched by this workflow. The orchestrator owns all launches and slot accounting. Instruct every task sub-agent not to spawn nested sub-agents; it must return to the orchestrator for the next implementation or review step. If 3 sub-agents are already running, wait for at least one to finish before launching another.

### Loop: repeat for each task

1. **Load project-scoped tasks**:
   - Detect the current project from local git context (`git rev-parse --show-toplevel`)
   - Run `ask list start.any:` first. If exactly one task is started, select and resume it directly; do not start another task. If multiple tasks are started, report their IDs and stop so the invalid state can be reconciled explicitly
   - Only when no task is started, run `ask ready | head` to list actionable tasks
   - Ignore completed/deleted tasks and non-actionable blocked items
   - If no task was already started, count the actionable tasks to determine the sub-agent threshold above (only 1 → work directly; 2+ → delegate per task)

2. **Pick the next task** (default strategy: `{{strategy|highest-impact}}`):
   - Resume the already-started task when present; otherwise choose one actionable task based on impact, urgency, and clarity
   - If two tasks are equivalent, prefer the one that unblocks other work
   - Run `ask info <id> 2>&1 | head -20` to preview the task — this caps the output at 20 lines so long descriptions do not flood the screen

3. **Mark the task started**:
   - Run `ask start <id>` unless the selected task is already started

4. **Execute the task** (mode depends on the threshold decided in step 1):

   **If working directly (one ready task, or resuming an already-started task):**
   - Implement the task yourself in the orchestrator's own context.
   - Run `ask info <id>` to load the full description and annotations.
   - Run `ask annotate <id> "<progress notes>"` as you work.
   - Complete all implementation, tests, and a git commit.
   - Then proceed to step 5 (you mark the task done yourself).

   **If delegating (2+ open tasks):**
   - Spawn a **new sub-agent** with a self-contained prompt that includes:
     - The task ID and a one-line summary of what the task is about
     - Instruction to run `ask info <id>` as its **first action** to get the full description and all annotations (do not paste the description inline — the sub-agent fetches it fresh, keeping the prompt short)
     - The absolute path of the project root
     - Instruction to run `ask annotate <id> "<progress notes>"` as it works
     - Instruction to commit all changes to git when done
     - Instruction to **not** mark the task done (the orchestrator does that)
     - Instruction to **not spawn other sub-agents**; the orchestrator owns the review cycle
   - The sub-agent must complete all implementation, tests, and a git commit before returning
   - Wait for the sub-agent to finish; if other workflow sub-agents are already running, enforce the 3-sub-agent concurrency limit before launching it

5. **Review, close, and record**:
   - Perform the self-review required by `agent-task-management`, then launch a fresh expert review sub-agent. Instruct the reviewer not to spawn other sub-agents.
   - The reviewer must check the implementation, test coverage, real behavior assertions, and plausible negative tests, and report every concrete issue.
   - Address every finding. In direct mode, fix it directly. In delegated mode, launch a fresh fixing sub-agent after the reviewer finishes; instruct it not to mark the task done or spawn other sub-agents.
   - If a review reports any findings, resolve them, repeat self-review, and launch another fresh review sub-agent whether or not the resolution changed files. Continue until a review reports no remaining issues.
   - Ensure all final changes are committed before closing the task.
   - Run `ask done <id>` to mark the task complete
   - Run `ask annotate <id> "<summary of what was delivered>"` if the sub-agent did not already add a final annotation

6. **Auto-progress**:
   - Immediately return to step 1 and select the next pending task
   - Stop when:
     - no actionable project tasks remain, or
     - `{{max_tasks}}` tasks have been completed (if provided), or
     - the sub-agent reports a hard blocker (surface it to the user, then stop)

7. **Final report**:
   - List completed task IDs/titles
   - List any skipped/blocked tasks with reasons
   - State what remains pending for the project

### Why sub-agents per task (when delegating)?

When there are 2+ tasks, each task runs in a **fresh context** with no carry-over from prior tasks. This:
- Prevents context drift (e.g. hallucinated paths) that accumulates over long sessions
- Matches the `agent-task-management` skill requirement: "Work on each new task must begin with a fresh context"
- Keeps the orchestrator's context minimal throughout the entire run

For a single task the fresh-context overhead is not worth it — the orchestrator implements it directly. The `agent-task-management` "fresh context" requirement is satisfied by compaction / a new session when spawning a sub-agent is not warranted.

### Important behavior requirements

- Do not ask the user to pick a task unless there is a true ambiguity or risk.
- Default to autonomous execution.
- Keep task scope tied to the current project.
- Never run more than 3 sub-agents concurrently, including review sub-agents.
- Never allow task implementation, fixing, or review sub-agents to spawn nested sub-agents; the orchestrator owns all launches.
- Never implement tasks in the orchestrator's own context **when delegating** (2+ open tasks) — always delegate to a sub-agent. When there is only 1 open task, implement directly instead of spawning a sub-agent.
- After the current task's implementation, review, fixes, and closure are complete, immediately move to the next task.
