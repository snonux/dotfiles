# Orchestrating task batches

Use this reference only when selecting, delegating, reviewing, or progressing
through several tasks, including `/work-on-tasks`.

Keep only one task in progress per project. You may work in parallel across
non-conflicting projects, with at most three sub-agents running. The
orchestrator owns implementation and review launches; task sub-agents must not
spawn sub-agents. Wait for a running agent to finish before starting another
when all three slots are occupied.

Start new work in a fresh context to prevent implementation context from
drifting between tasks. The exception is a single or resumed task: when a task
is already started, resume it in the orchestrator's context; when exactly one
task is ready, implement it directly. The detailed selection rule is in
[2-start-task.md](2-start-task.md).

For each task, create it, start it, annotate progress, meet the completion
criteria, and have the orchestrator run fresh-context review(s) until one finds
no remaining issues. Commit the in-scope changes, mark the task done, then
check for the next started or ready task. The completion and review procedure
is in [3-complete-task.md](3-complete-task.md).
