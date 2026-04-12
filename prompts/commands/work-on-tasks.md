# /work-on-tasks

**Description:** Automatically work through tasks for the current git project using the `agent-task-management` skill. The command selects the best pending task, delegates its execution to a fresh sub-agent, completes it, and then auto-progresses to the next task until no actionable tasks remain.

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

I want you to automatically execute tasks to work for the **current git project** from start to finish.

### Your role: orchestrator only

You are the **orchestrator**. You pick tasks, mark them started, launch a sub-agent to do the implementation, then mark them done. You do **not** implement tasks yourself. This keeps your context small and lets each task run with a clean slate.

### Loop: repeat for each task

1. **Load project-scoped tasks**:
   - Detect the current project from local git context (`git rev-parse --show-toplevel`)
   - Run `ask ready | head` to list actionable tasks
   - Ignore completed/deleted tasks and non-actionable blocked items

2. **Pick the next task** (default strategy: `{{strategy|highest-impact}}`):
   - Choose one actionable task based on impact, urgency, and clarity
   - If two tasks are equivalent, prefer the one that unblocks other work
   - Run `ask info <id> 2>&1 | head -20` to preview the task — this caps the output at 20 lines so long descriptions do not flood the screen

3. **Mark the task started**:
   - Run `ask start <id>`

4. **Delegate to a fresh sub-agent**:
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

### Why sub-agents per task?

Each task runs in a **fresh context** with no carry-over from prior tasks. This:
- Prevents context drift (e.g. hallucinated paths) that accumulates over long sessions
- Matches the `agent-task-management` skill requirement: "Work on each new task must begin with a fresh context"
- Keeps the orchestrator's context minimal throughout the entire run

### Important behavior requirements

- Do not ask the user to pick a task unless there is a true ambiguity or risk.
- Default to autonomous execution.
- Keep task scope tied to the current project.
- Never implement tasks in the orchestrator's own context — always delegate to a sub-agent.
- After each sub-agent completes, immediately move to the next task.
