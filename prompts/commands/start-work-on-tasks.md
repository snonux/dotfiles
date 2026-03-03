# /start-work-on-tasks

**Description:** Automatically work through Taskwarrior tasks for the current git project using the `taskwarrior-task-management` skill. The command selects the best pending task, starts it, executes it, completes it, and then auto-progresses to the next task until no actionable tasks remain.

**Parameters:**
- strategy (optional): How to choose tasks when multiple are available (e.g., "highest-impact", "priority", "due-date", "quick-win")
- max_tasks (optional): Safety limit for how many tasks to process in one run

**Example usage:**
- `/start-work-on-tasks`
- `/start-work-on-tasks highest-impact`
- `/start-work-on-tasks priority 5`

---

## Prompt

Use the `taskwarrior-task-management` skill for this entire workflow.

I want you to automatically execute Taskwarrior work for the **current git project** from start to finish.

1. **Load project-scoped tasks**:
   - Detect the current project from local git context
   - List pending Taskwarrior tasks for that project
   - Ignore completed/deleted tasks and non-actionable blocked items

2. **Pick the next task** (default strategy: `{{strategy|highest-impact}}`):
   - Choose one actionable task based on impact, urgency, and clarity
   - If two tasks are equivalent, prefer the one that unblocks other work

3. **Start and execute it**:
   - Mark the task as started
   - Perform the implementation work needed to complete it
   - Keep updates concise and action-focused while working

4. **Close and record**:
   - Mark the task complete when done
   - Add a brief annotation summarizing what was delivered

5. **Auto-progress loop**:
   - Immediately return to step 1 and select the next pending task
   - Continue until:
     - no actionable project tasks remain, or
     - `{{max_tasks}}` is reached (if provided), or
     - a hard blocker is encountered

6. **Final report**:
   - List completed task IDs/titles
   - List any skipped/blocked tasks with reasons
   - State what remains pending for the project

Important behavior requirements:
- Do not ask me to pick a task unless there is a true ambiguity or risk.
- Default to autonomous execution.
- Keep task scope tied to the current project.
- After each completion, automatically move to the next task.
