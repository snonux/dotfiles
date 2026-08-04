# /work-on-tasks

**Description:** Automatically work through tasks for the current git project using the `agent-task-management` skill. The command selects the best pending task, executes it (delegating to a fresh sub-agent when there are 4+ open tasks, or implementing directly when there are fewer than 4), completes it, and then auto-progresses to the next task until no actionable tasks remain.

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

**Sub-agent threshold:** Before starting the loop, count the actionable tasks from `ask ready`. Decide once, up front:

- **Fewer than 4 open tasks → work directly.** Do **not** spawn sub-agents. Implement each task yourself in the orchestrator's own context, running `ask start <id>`, doing the work, committing, and `ask done <id>` inline. The fresh-context overhead is not worth it for a small list, and staying in one context avoids re-loading project context for every task.
- **4 or more open tasks → delegate per task.** Use the sub-agent-per-task flow described below. This keeps your context small and lets each task run with a clean slate.

Whatever mode you are in, you still pick tasks, mark them started/done, commit, and auto-progress.

### Loop: repeat for each task

1. **Load project-scoped tasks**:
   - Detect the current project from local git context (`git rev-parse --show-toplevel`)
   - Run `ask ready | head` to list actionable tasks
   - Ignore completed/deleted tasks and non-actionable blocked items
   - Count the actionable tasks to determine the sub-agent threshold above (fewer than 4 → work directly; 4+ → delegate per task)

2. **Pick the next task** (default strategy: `{{strategy|highest-impact}}`):
   - Choose one actionable task based on impact, urgency, and clarity
   - If two tasks are equivalent, prefer the one that unblocks other work
   - Run `ask info <id> 2>&1 | head -20` to preview the task — this caps the output at 20 lines so long descriptions do not flood the screen

3. **Mark the task started**:
   - Run `ask start <id>`

4. **Execute the task** (mode depends on the threshold decided in step 1):

   **If working directly (fewer than 4 open tasks):**
   - Implement the task yourself in the orchestrator's own context.
   - Run `ask info <id>` to load the full description and annotations.
   - Run `ask annotate <id> "<progress notes>"` as you work.
   - Complete all implementation, tests, and a git commit.
   - Then proceed to step 5 (you mark the task done yourself).

   **If delegating (4+ open tasks):**
   - Spawn a **new sub-agent** with a self-contained prompt that includes:
     - The task ID and a one-line summary of what the task is about
     - Instruction to run `ask info <id>` as its **first action** to get the full description and all annotations (do not paste the description inline — the sub-agent fetches it fresh, keeping the prompt short)
     - The absolute path of the project root
     - Instruction to run `ask annotate <id> "<progress notes>"` as it works
     - Instruction to commit all changes to git when done
     - Instruction to **not** mark the task done (the orchestrator does that)
   - The sub-agent must complete all implementation, tests, and a git commit before returning
   - Wait for the sub-agent to finish

5. **Close and record**:
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

When there are 4+ tasks, each task runs in a **fresh context** with no carry-over from prior tasks. This:
- Prevents context drift (e.g. hallucinated paths) that accumulates over long sessions
- Matches the `agent-task-management` skill requirement: "Work on each new task must begin with a fresh context"
- Keeps the orchestrator's context minimal throughout the entire run

For fewer than 4 tasks the fresh-context overhead is not worth it — the orchestrator implements them directly. The `agent-task-management` "fresh context" requirement is satisfied by compaction / a new session when spawning a sub-agent is not warranted.

### Important behavior requirements

- Do not ask the user to pick a task unless there is a true ambiguity or risk.
- Default to autonomous execution.
- Keep task scope tied to the current project.
- Never implement tasks in the orchestrator's own context **when delegating** (4+ open tasks) — always delegate to a sub-agent. When there are fewer than 4 open tasks, implement directly instead of spawning sub-agents.
- After each sub-agent completes, immediately move to the next task.
