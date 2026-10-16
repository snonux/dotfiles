# Complete task

Use with `00-cli.md`, `00-project-scope.md`, and `verification-honesty.md`.

## Completion criteria (required before "done")

A task is **not** considered done until all of the following are true:

- **Best practices** — the codebase (or changed parts) follows the project's best practices.
- **Compilable** — all code compiles successfully (e.g. full build succeeds).
- **Tests pass** — all tests pass (e.g. full test suite green).
- **Negative tests where plausible** — for any new or changed tests, include negative tests (invalid input, errors, failure cases) wherever plausible.
- **All changes committed to git** — on completion of the task, all changes must be committed to git (e.g. a single commit or logical commits with a clear message referencing the task).

If any of these fail, fix the issues and recheck. Do not mark the task complete until they are all met.

## What the review sub-agent must check

Review sub-agents **must always**:

- **Unit test coverage** — double-check that coverage is as desired for the changed or added code (e.g. project expectations or thresholds are met).
- **Tests are testing real things** — confirm that tests exercise real behavior and assertions, not only mocks. Flag tests that merely assert on mocks or stubs without verifying real logic, integration points, or outcomes. Tests should give confidence that the code actually works.
- **Negative tests where plausible** — for all tests created, ensure there are also negative tests (invalid input, error paths, edge cases that should fail, unauthorized access, etc.) wherever plausible. If positive/happy-path tests exist but no corresponding negative tests, flag it unless there is a clear reason none are plausible.

Include these checks in the sub-agent's review report.

## Self-review before any sub-agent handoff

**Before signing off work to sub-agents for review** (before the first review, and again before the second review if one is needed), the main agent must **ask itself**:

- Did everything I did make sense?
- Isn't there a better way to do it?

If the answer suggests improvements or inconsistencies, address them first. Only then hand off to the sub-agent. Do not skip this step.

## Skipping the sub-agent review (only when the user asks)

The sub-agent review is the default and stays on unless the user **explicitly**
asks to skip it (e.g. "no reviews", "skip the review", "don't review completed
tasks") — usually to speed up the work. Never skip it on your own initiative,
and do not infer the request from time pressure, a small diff, or a task
annotation.

When the user has asked to skip the review:

- **Do not spawn review sub-agents** — neither the first review nor follow-up
  reviews. Steps 1–4 of "Before marking complete" reduce to the self-review.
- **Everything else still applies**: the completion criteria (best practices,
  build, tests, negative tests), the self-review, `verification-honesty.md`,
  in-scope-only commits, and the git commit before `ask done <id>`. With no
  reviewer behind you, the self-review is the only check on test coverage and
  test quality, so apply "What the review sub-agent must check" to your own work.
- **The user's request overrides the "sub-agent reviews pass" wording** in the
  standard "Agent workflow" task annotation (see `1-create-task.md`).
- **Scope it as the user stated it** — a single task, the current batch, or the
  rest of the session. If the scope is unstated, apply it to the tasks worked on
  under the current request. It does not carry over to later sessions.
- **Record it in an annotation** so the task history is honest:

  ```bash
  ask annotate <id> "Sub-agent review skipped on user request; self-review only."
  ```

## Commit only in-scope files (pre-existing dirty worktree)

The worktree may already be dirty **before this task starts** — e.g. the user's
own unrelated edits to `.gitignore`, `start.sh`, or other files. Those changes
are **not yours to commit**. (This is distinct from a *stalled worker* that left
broken, half-applied edits mid-task — for that, see `6-recover-stalled-task.md`.
Here the dirty changes are intact, unrelated user work, not corruption.)

To avoid committing unrelated files (with parallel workers sharing one worktree,
a sibling worker's in-progress edits are also out-of-scope for you):

1. **At task start, and again before committing, run `git status`** and classify
   every dirty path:

   - **In-scope** — files this task created or modified. These get committed.
   - **Out-of-scope** — pre-existing or unrelated changes (the user's own work).
     These get **left exactly as they were**.

   ```bash
   git status --short            # full picture of what is dirty
   ```

2. **Stage only the in-scope files by explicit path.** Never blanket-add when the
   worktree had pre-existing unrelated changes:

   ```bash
   git add path/to/changed_file path/to/other_changed_file   # explicit paths only
   ```

   Do **not** use `git add -A`, `git add .`, or `git commit -a` here — they would
   sweep up the user's unrelated edits into your commit.

3. **Never commit unrelated files.** Leave out-of-scope changes untouched in the
   worktree; do not stage, commit, revert, or stash them.

4. **Record the in-scope/out-of-scope decision in an annotation** so the history
   is honest and the next worker knows what was deliberately left alone (see
   `4-annotate-update-task.md`):

   ```bash
   ask annotate <id> "Committed in-scope: <files>. Left out-of-scope (unrelated, untouched): <files>."
   ```

If you cannot confidently tell whether a dirty file is in-scope, treat it as
out-of-scope and leave it alone rather than risk committing the user's work.

## Review budget and convergence

Reviews must converge. An open-ended "find every flaw until a review is clean" loop never terminates: each round finds smaller issues, and every round costs a rebuild and test run. Follow these rules unless the user or the task explicitly asks for more:

- **At most two review rounds per task**: one full review, and a second, narrow confirmation round only when the first found blocking issues.
- **Blocking** means one of:
  - a product defect: wrong behaviour, a crash, data loss, a security issue, a regression;
  - a test or oracle that can pass while the behaviour is wrong (a false pass), or a missing test for an acceptance criterion;
  - a build, lint or test failure;
  - a documentation claim that is false about what the product does or what was verified.
- **Non-blocking** means everything else: wording, style, naming, extra hardening, nicer diagnostics, additional evidence or provenance records, duplicated helpers, hypothetical edge cases outside the acceptance criteria. Fix it inline if cheap, otherwise drop it or create a follow-up task. It never triggers another round.
- **Do not raise the bar mid-task.** Neither the orchestrator nor the reviewer adds requirements the task did not state (for example identity hashes, evidence sha256 tables, clause-to-test tables, negative-control suites). If such a requirement is worth having, create a separate task for it.
- **Out-of-scope discoveries** (bugs in other areas, shared helpers, flaky unrelated tests) become new tasks with full context; they do not extend the current task's review.
- Tell every reviewer these rules in its prompt, including the round number and that it must classify each finding.

## Before marking complete (after criteria are met)

**Once the completion criteria above are met:**

If the user asked to skip the review, do the self-review from step 1, skip the
rest of steps 1–4, and continue at step 5 (see "Skipping the sub-agent review").

1. **Self-review** (see above). The orchestrator then spawns a **sub-agent** with **fresh context** (no prior conversation). If the current worker is itself a task implementation sub-agent, it returns to the orchestrator after self-review instead of spawning the reviewer.
2. The sub-agent's role is an **expert critical reviewer**. Its **only goal** is to find bugs and design flaws in the subject under review. It must be thorough, skeptical, and uncompromising. The sub-agent reviews the diff, code, or deliverables (including test coverage and test quality — see "What the review sub-agent must check") and **reports back** to the main agent with every concrete bug, design flaw, missed edge case, or test-quality issue it found, **each classified as blocking or non-blocking** (see "Review budget and convergence" below). Praise and suggestions for enhancement should only be included when they directly illuminate an underlying flaw or risk. The reviewer judges the change against the task's acceptance criteria; it must not invent new requirements (extra evidence formats, provenance hashes, documentation tables, stylistic rewrites) that the task did not ask for.
   - The orchestrator owns this review launch and all worker accounting. Task implementation and review sub-agents must not spawn nested sub-agents.
   - Reviewers may run in parallel with other workers; there is no fixed cap unless the user states one. Apply the memory guard in [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md) before launching each reviewer, and wait for a running agent to finish if memory is below the floor.
3. Main agent **resolves all blocking findings** — no exceptions. Fix every valid blocking issue; a response without a code change is acceptable only when it demonstrates that the finding is not an issue. Non-blocking findings are fixed inline when cheap, otherwise dropped or recorded as a follow-up task; they never trigger another review round.
4. If the first review reported **blocking** findings: **Self-review again** (see above), then the orchestrator **spawns one more sub-agent** (fresh context) to review the updated code and responses. This second review only confirms that the blocking findings are resolved and checks the fix diff for new blocking defects; it must not re-audit the whole task or raise non-blocking items. **At most two review rounds per task.** If the first review reports only non-blocking findings, or none, there is no second round.
   - If the second review still reports a blocking issue, fix it and verify the fix with tests yourself; do not launch a third review. If the issue cannot be fixed within scope, record it as a new task (`ask add`, with full context) or as an annotated blocker, and surface it to the user. Never loop.
5. **Commit all changes to git** (e.g. `git add` and `git commit` with a message that references the task). Do not mark the task complete with uncommitted changes. Stage **only the in-scope files by explicit path** — never `git add -A`/`git add .` when the worktree had pre-existing unrelated changes (see "Commit only in-scope files" above).
6. Only then:

```bash
ask done <id>
```

Use the alias ID from the selection step or current task details when marking the task complete.

7. **Automatically progress to the next task in the list.** After marking the task done, load `00-cli.md`, `00-project-scope.md`, and `2-start-task.md`, then run `ask list start.any:`. Resume any started task that has no live worker first. Then use `ask ready` to pick new tasks for the free worker slots (respecting dependencies, the conflict rules, and the memory guard in [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md)). Do not stop when another task is available.

## Conventions

- When creating or changing tests, add negative tests (invalid input, errors, failure paths) wherever plausible; the review sub-agent will check for this.
- A task is not done until: best practices met, code compiles, all tests pass, negative tests included where plausible, all blocking review findings are resolved (including coverage and test-quality checks) within the two-round review budget, **and all changes are committed to git**.
- **Review opt-out.** The review-related conventions in this list apply unless the user explicitly asked to skip the sub-agent review; then the self-review replaces it and the skip is recorded in an annotation (see "Skipping the sub-agent review").
- Before every sub-agent review handoff, do the self-review: "Did it all make sense? Is there a better way?" Fix anything that comes up, then hand off.
- **On completion, commit all changes to git** before running `ask done <id>`; do not leave uncommitted work when marking a task complete.
- **Commit only in-scope files.** Check `git status` first, stage in-scope files by explicit path (essential when parallel workers share one worktree), never `git add -A`/`git add .` over a pre-existing dirty worktree, and never commit the user's unrelated changes. Record the in-scope/out-of-scope split in an annotation (see "Commit only in-scope files").
- Complete with `ask done <id>` only after completion criteria, self-review(s), all blocking review findings are resolved, and the git commit is complete. Run at most one follow-up review, only after a first review that reported blocking findings (see "Review budget and convergence").
- When completing a task, note which tasks were unblocked (dependents that became ready), if any.
- **After completing a task, automatically progress to the next task in the list** (when all tests and required sub-agent review(s) pass and the task is done). Check `ask list start.any:` first and resume started tasks that have no live worker; only then select from `ask ready`, within the parallelism policy in [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md). Do not stop unless no next task is available or the user asks to stop.
