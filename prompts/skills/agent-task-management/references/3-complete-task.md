# Complete task

Use with `00-context.md`. Project name and global rules apply.

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

**Before signing off work to sub-agents for review** (before the first review, and again before a second review if needed), the main agent must **ask itself**:

- Did everything I did make sense?
- Isn't there a better way to do it?

If the answer suggests improvements or inconsistencies, address them first. Only then hand off to the sub-agent. Do not skip this step.

## Commit only in-scope files (pre-existing dirty worktree)

The worktree may already be dirty **before this task starts** — e.g. the user's
own unrelated edits to `.gitignore`, `start.sh`, or other files. Those changes
are **not yours to commit**. (This is distinct from a *stalled worker* that left
broken, half-applied edits mid-task — for that, see `6-recover-stalled-task.md`.
Here the dirty changes are intact, unrelated user work, not corruption.)

To avoid committing unrelated files:

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

## Before marking complete (after criteria are met)

**Once the completion criteria above are met:**

1. **Self-review** (see above). The orchestrator then spawns a **sub-agent** with **fresh context** (no prior conversation). If the current worker is itself a task implementation sub-agent, it returns to the orchestrator after self-review instead of spawning the reviewer.
2. The sub-agent's role is an **expert critical reviewer**. Its **only goal** is to find bugs and design flaws in the subject under review. It must be thorough, skeptical, and uncompromising. The sub-agent reviews the diff, code, or deliverables (including test coverage and test quality — see "What the review sub-agent must check") and **reports back** to the main agent with every bug, design flaw, missed edge case, suspicious pattern, or test-quality issue it found. Praise and suggestions for enhancement should only be included when they directly illuminate an underlying flaw or risk.
   - The orchestrator owns this review launch and all concurrency accounting. Task implementation and review sub-agents must not spawn nested sub-agents.
   - Keep at most 3 sub-agents running concurrently across implementation and review work. If all 3 slots are occupied, wait for one to finish before launching the reviewer.
3. Main agent **resolves all review comments** from the sub-agent — no exceptions. Fix every valid issue; a response without a code change is acceptable only when it demonstrates that the finding is not an issue.
4. If the review reported any findings: **Self-review again** (see above), then the orchestrator **spawns another sub-agent** (fresh context again) to **review the updated code and responses** (including test coverage and test quality) and confirm the resolutions. Repeat this step after every review that reports findings, whether or not addressing them changed code, until a fresh review reports no remaining issues.
5. **Commit all changes to git** (e.g. `git add` and `git commit` with a message that references the task). Do not mark the task complete with uncommitted changes. Stage **only the in-scope files by explicit path** — never `git add -A`/`git add .` when the worktree had pre-existing unrelated changes (see "Commit only in-scope files" above).
6. Only then:

```bash
ask done <id>
```

Use the alias ID from the selection step or current task details when marking the task complete.

7. **Automatically progress to the next task in the list.** After marking the task done, load `00-context.md` and `2-start-task.md`, then run `ask list start.any:`. Resume a started task directly if present. Only when none is started, use `ask ready` to pick the next task (respecting dependencies and the "one task in progress" rule). Do not stop when another task is available.

## Conventions

- When creating or changing tests, add negative tests (invalid input, errors, failure paths) wherever plausible; the review sub-agent will check for this.
- A task is not done until: best practices met, code compiles, all tests pass, negative tests included where plausible, all review comments are resolved (including coverage and test-quality checks), a fresh review reports no remaining issues, **and all changes are committed to git**.
- Before every sub-agent review handoff, do the self-review: "Did it all make sense? Is there a better way?" Fix anything that comes up, then hand off.
- **On completion, commit all changes to git** before running `ask done <id>`; do not leave uncommitted work when marking a task complete.
- **Commit only in-scope files.** Check `git status` first, stage in-scope files by explicit path, never `git add -A`/`git add .` over a pre-existing dirty worktree, and never commit the user's unrelated changes. Record the in-scope/out-of-scope split in an annotation (see "Commit only in-scope files").
- Complete with `ask done <id>` only after completion criteria, self-review(s), all review comments are resolved, a fresh review reports no remaining issues, and the git commit is complete. Run a follow-up sub-agent review after any review that reports findings, even when resolving them required no code change.
- When completing a task, note which tasks were unblocked (dependents that became ready), if any.
- **After completing a task, automatically progress to the next task in the list** (when all tests and required sub-agent review(s) pass and the task is done). Check `ask list start.any:` first and resume a started task directly; only then select from `ask ready`. Do not stop unless no next task is available or the user asks to stop.
