# Complete task

Use with `00-cli.md`, `00-project-scope.md`, and `verification-honesty.md`.

Most of the time the role card is enough: [card-worker.md](card-worker.md) for
the agent doing the work, [card-reviewer.md](card-reviewer.md) for the
reviewer. This file is the detail behind them. Related situations have their
own files, so load them only when they apply:

- the working tree was dirty before the task started: [3c-commit-in-scope.md](3c-commit-in-scope.md)
- reviews do not converge, or the user wants batch reviews or none: [3d-review-budget.md](3d-review-budget.md)

## Completion criteria (required before "done")

A task is **not** considered done until all of the following are true:

- **Best practices** — the codebase (or changed parts) follows the project's best practices.
- **Compilable** — all code compiles successfully (e.g. full build succeeds).
- **Tests pass** — the tests for the changed code pass, and the full suite has passed once before the task is closed (the worker's single run at the end, or the orchestrator's integration run).
- **Negative tests where plausible** — for any new or changed tests, include negative tests (invalid input, errors, failure cases) wherever plausible.
- **Change proven** — for bug fixes and behaviour changes, an annotation records the test that failed before the change for the expected reason; for refactors, the pinning tests passed unchanged (see "Prove the change (red first)" in [2-start-task.md](2-start-task.md)).
- **All changes committed to git** — on completion of the task, all changes must be committed to git, in one commit or a few small ordered ones. Each message references the task and says **why** the change was made, **what** changed, and **how it was proven** (the tests or checks that ran).

If any of these fail, fix the issues and recheck. Do not mark the task complete until they are all met.

## What the review sub-agent must check

Paste [card-reviewer.md](card-reviewer.md) into the reviewer's prompt, with
the task ID, the base commit (the commit before the task's first commit), and
the round number. The card holds the steps, what counts as blocking, and the
report format. [3b-review-checklist.md](3b-review-checklist.md) is the detail
behind it.

## Self-review before any sub-agent handoff

**Before signing off work to sub-agents for review** (before the first review, and again before the second review if one is needed), the main agent must **ask itself**:

- Did everything I did make sense?
- Isn't there a better way to do it?

If the answer suggests improvements or inconsistencies, address them first. Only then hand off to the sub-agent. Do not skip this step.

## Commit message template

```text
<short summary> (task <id>)

Why: <the problem or goal>
What: <what changed>
Proof: <tests or checks that ran, and their result>
```

## Before marking complete (after criteria are met)

**Who does what.** A worker launched by an orchestrator does steps 1 and 2,
then reports and stops. It never launches a reviewer, runs `ask done`, or
pushes. The orchestrator, or an agent working alone, does every step.

1. **Self-review** (see above).
2. **Commit** the in-scope files by explicit path, using the commit message
   template. The reviewer reads `git diff <base>..HEAD`, so work that is not
   committed is invisible to it. If the tree was dirty before the task, see
   [3c-commit-in-scope.md](3c-commit-in-scope.md).
3. **Review.** Launch one fresh-context reviewer whose only goal is to find
   bugs and design flaws. Paste [card-reviewer.md](card-reviewer.md) into its
   prompt with the task ID, the base commit, and the round number. It judges
   the change against the task's acceptance criteria and must not invent
   requirements. Reviewers count as workers for the per-wave memory guard.
   With no sub-agent tool, or when the user asked to skip reviews, apply the
   card to your own work instead ([3d-review-budget.md](3d-review-budget.md)).
4. **Fix every blocking finding**, in new commits. A reply without a code
   change is acceptable only when it shows the finding is not a defect.
   Non-blocking findings are fixed inline when cheap, otherwise dropped or
   recorded as a follow-up task; they never trigger another round. A
   suggestion to delete or weaken a test or a check is never "cheap": verify
   its claim yourself (does something else really cover it?) or drop it. In
   the first real run, a reviewer's "these two checks are duplicates" was
   passed on unverified and cost the second review round.
5. **Second round only if round one had blocking findings.** It confirms the
   fixes and checks the fix diff for new blocking defects, nothing else.
   **At most two rounds.** If something blocking remains, fix it and verify
   it with tests yourself. If it cannot be fixed within scope, create a new
   task with full context; if it needs the user's decision, park this task
   (`ask park <id> "<question>"`). Never start a third round.
6. **Close**, with a one-line delivery summary (recorded as an annotation, so
   no separate `ask annotate` is needed):

   ```bash
   ask done <id> "Delivered: <what changed and how it was proven>"
   ```

7. **Take the next task.** Run `ask list start.any:` and resume any started
   task without a live worker; then pick from `ask ready`. Do not stop while
   a task is available. (A skill such as next-auto-task may insert its own
   step between 6 and 7.)

## Conventions

- When creating or changing tests, add negative tests (invalid input, errors, failure paths) wherever plausible; the review sub-agent will check for this.
- A task is not done until: best practices met, code compiles, all tests pass, negative tests included where plausible, the change proven (red first or pinned behaviour), all blocking review findings are resolved (including coverage and test-quality checks) within the two-round review budget, **and all changes are committed to git**.
- **Review opt-out.** The review-related conventions in this list apply unless the user explicitly asked to skip the sub-agent review; then the self-review replaces it and the skip is recorded in an annotation (see [3d-review-budget.md](3d-review-budget.md)).
- Before every sub-agent review handoff, do the self-review: "Did it all make sense? Is there a better way?" Fix anything that comes up, then hand off.
- **On completion, commit all changes to git** before running `ask done <id>`; do not leave uncommitted work when marking a task complete.
- **Commit only in-scope files.** Check `git status` first, stage in-scope files by explicit path (essential when parallel workers share one worktree), never `git add -A`/`git add .` over a pre-existing dirty worktree, and never commit the user's unrelated changes. Record the in-scope/out-of-scope split in an annotation (see [3c-commit-in-scope.md](3c-commit-in-scope.md)).
- Complete with `ask done <id>` only after completion criteria, self-review(s), all blocking review findings are resolved, and the git commit is complete. Run at most one follow-up review, only after a first review that reported blocking findings (see [3d-review-budget.md](3d-review-budget.md)).
- When completing a task, note which tasks were unblocked (dependents that became ready), if any.
- **After completing a task, automatically progress to the next task in the list** (when all tests and required sub-agent review(s) pass and the task is done). Check `ask list start.any:` first and resume started tasks that have no live worker; only then select from `ask ready`, within the parallelism policy in [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md). Do not stop unless no next task is available or the user asks to stop.
