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

## Before marking complete (after criteria are met)

**Once the completion criteria above are met:**

1. **Self-review** (see above). Then spawn a **sub-agent** with **fresh context** (no prior conversation).
2. Sub-agent reviews the diff, code, or deliverables for the task (including test coverage and test quality — see "What the review sub-agent must check") and **reports back** to the main agent (review comments, suggestions, issues).
3. Main agent **addresses all review comments** from the sub-agent — no exceptions. Fix or respond to every point.
4. If code changed after review comments were addressed: **Self-review again** (see above), then **spawn another sub-agent** (fresh context again) to **review the updated code** (including test coverage and test quality) and confirm the fixes. If this follow-up review finds further issues and additional code changes are made, repeat this step until the review is satisfied.
5. **Commit all changes to git** (e.g. `git add` and `git commit` with a message that references the task). Do not mark the task complete with uncommitted changes.
6. Only then:

```bash
ask done <id>
```

Use the alias ID from the selection step or current task details when marking the task complete.

7. **Automatically progress to the next task in the list.** After marking the task done, if there are more agent-managed tasks in the project (e.g. `ask list` shows pending/ready tasks), start the next one: load `00-context.md` and `2-start-task.md`, pick the next task from the list (respecting dependencies and "one task in progress" rule), and begin work on it. Do not stop after completing a task when a next task is available — continue to the next task in the list.

## Conventions

- When creating or changing tests, add negative tests (invalid input, errors, failure paths) wherever plausible; the review sub-agent will check for this.
- A task is not done until: best practices met, code compiles, all tests pass, negative tests included where plausible, and all first-round review comments are addressed (including coverage and test-quality checks), **and all changes are committed to git**. If code changed after review comments, a second sub-agent review must confirm the updated code.
- Before every sub-agent review handoff, do the self-review: "Did it all make sense? Is there a better way?" Fix anything that comes up, then hand off.
- **On completion, commit all changes to git** before running `ask done <id>`; do not leave uncommitted work when marking a task complete.
- Complete with `ask done <id>` only after completion criteria, self-review(s), first review, addressing all comments, and git commit are satisfied. Add a follow-up sub-agent review only when code changed after review comments.
- When completing a task, note which tasks were unblocked (dependents that became ready), if any.
- **After completing a task, automatically progress to the next task in the list** (when all tests and required sub-agent review(s) pass and the task is done). Start the next ready task from `ask ready`; do not stop unless no next task is available or the user asks to stop.
