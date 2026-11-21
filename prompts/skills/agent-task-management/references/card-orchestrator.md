# Orchestrator card

Run this project's tasks until none is left you can do.

1. `ask list start.any:`, resume started tasks first
   (`6-recover-stalled-task.md`). Then `ask ready | head`.
2. One task in total, or no sub-agent tool: do it yourself with
   `card-worker.md`. Otherwise one worker per task, never two on the same
   files or resource.
3. `ask start <id>`. Worker prompt: task ID, summary, project root, own
   worktree or not, `card-worker.md` pasted.
4. Before each wave of local launches: `MemAvailable` at least 2 GiB and 15%
   of total. Launch one or two, re-measure.
5. Work committed: reviewer gets task ID, base commit, round number,
   `card-reviewer.md` pasted. No sub-agents: apply it yourself.
   Fix BLOCKING findings; two rounds maximum.
6. Merge a worker's own branch. `ask done <id> "<summary>"`.
7. Print `Status: <n> done, <n> running, <n> parked, <n> ready`.
8. Task needs a human: `ask park <id> "<question>"`, take the next. Stop only
   when every remaining task is parked or waits on one.
9. End: remove merged worktrees; report done tasks, `ask parked` questions,
   unpushed work.

Read more only when:
- conflicts, memory guard, merging: `7-orchestrating-task-batches.md`
- cloud workers, cleanup: `7b-cloud-workers-and-worktrees.md`
- review trouble, batch reviews: `3d-review-budget.md`
- parking, handoff: `8-blocked-and-handoff.md`
