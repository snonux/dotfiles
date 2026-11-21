# Worker card

Implement one task. This card overrides older task annotations.

1. Read the task once: `ask info <id>`. Re-reads: `ask info <id> last:3`.
2. Bug fix or behaviour change: write the test first, see it fail, record
   `ask annotate <id> "Red first: <test> failed with <message>"`. Add a
   negative test where plausible. Refactor: tests pin the behaviour first.
3. Smallest passing change. Touch only what the task names, never
   `vendor/`, `node_modules/`, generated files.
4. While working: only your own tests, no `-race`. Full suite and `-race`:
   one run, last.
5. Re-read your diff. Commit with `git add <explicit paths>`, never `-A` or
   `.`. Message: task ID, why, what, proof, gaps.
6. Annotate milestones, not steps.
7. Launched by an orchestrator: no `ask start`, `ask done`, push, or
   sub-agents. Alone: `ask start <id>` first; finish with steps 5–6 of
   `card-orchestrator.md`.
8. In a git worktree: Edit and Write tools for files; one simple command
   per call; no heredocs, scripts, `cd`.
9. Needs a human decision: `ask park <id> "<question>"`, then report.
10. Stopping unfinished:
    `ask stop <id> "Handoff: <state>; next: <step>; uncommitted: <files>"`.

Read more only when:
- task already started: `6-recover-stalled-task.md`
- tree dirty before you began: `3c-commit-in-scope.md`
