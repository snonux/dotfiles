# Complete task

Use with `00-context.md`. Project name and global rules apply. Only complete tasks that have both `project:<name>` and the `+agent` tag — use task IDs from `project:<name> +agent` filtered lists.

## Completion criteria (required before “done”)

A task is **not** considered done until all of the following are true:

- **Best practices** — the codebase (or changed parts) follows the project’s best practices.
- **Compilable** — all code compiles successfully (e.g. full build succeeds).
- **Tests pass** — all tests pass (e.g. full test suite green).
- **Negative tests where plausible** — for any new or changed tests, include negative tests (invalid input, errors, failure cases) wherever plausible.
- **All changes committed to git** — on completion of the task, all changes must be committed to git (e.g. a single commit or logical commits with a clear message referencing the task).

If any of these fail, fix the issues and recheck. Do not mark the task complete until they are all met.

## What the review sub-agent must check

Review sub-agents (first and second review) **must always**:

- **Unit test coverage** — double-check that coverage is as desired for the changed or added code (e.g. project expectations or thresholds are met).
- **Tests are testing real things** — confirm that tests exercise real behavior and assertions, not only mocks. Flag tests that merely assert on mocks or stubs without verifying real logic, integration points, or outcomes. Tests should give confidence that the code actually works.
- **Negative tests where plausible** — for all tests created, ensure there are also negative tests (invalid input, error paths, edge cases that should fail, unauthorized access, etc.) wherever plausible. If positive/happy-path tests exist but no corresponding negative tests, flag it unless there is a clear reason none are plausible.

Include these checks in the sub-agent’s review report.

## Self-review before any sub-agent handoff

**Before signing off work to sub-agents for review** (before the first review and again before the second), the main agent must **ask itself**:

- Did everything I did make sense?
- Isn’t there a better way to do it?

If the answer suggests improvements or inconsistencies, address them first. Only then hand off to the sub-agent. Do not skip this step.

## Before marking complete (after criteria are met)

**Once the completion criteria above are met:**

1. **Self-review** (see above). Then spawn a **sub-agent** with **fresh context** (no prior conversation).
2. Sub-agent reviews the diff, code, or deliverables for the task (including test coverage and test quality — see “What the review sub-agent must check”) and **reports back** to the main agent (review comments, suggestions, issues).
3. Main agent **addresses all review comments** from the sub-agent — no exceptions. Fix or respond to every point.
4. **Self-review again** (see above). Then **spawn another sub-agent** (fresh context again) to **review the code again** (including test coverage and test quality) and confirm the fixes. If this second review finds further issues, address them and repeat the sub-agent review until the review is satisfied.
5. **Commit all changes to git** (e.g. `git add` and `git commit` with a message that references the task). Do not mark the task complete with uncommitted changes.
6. Only then:

```bash
task <id> done
```

## Conventions

- When creating or changing tests, add negative tests (invalid input, errors, failure paths) wherever plausible; the review sub-agent will check for this.
- A task is not done until: best practices met, code compiles, all tests pass, negative tests included where plausible, all first-round review comments addressed (including coverage and test-quality checks), a second sub-agent review has confirmed the code, **and all changes are committed to git**.
- Before every sub-agent review handoff, do the self-review: “Did it all make sense? Is there a better way?” Fix anything that comes up, then hand off.
- **On completion, commit all changes to git** before running `task <id> done`; do not leave uncommitted work when marking a task complete.
- Complete with `task <id> done` only after completion criteria, self-review(s), first review, addressing all comments, follow-up sub-agent review, and git commit are satisfied.
- When completing a task, note which tasks were unblocked (dependents that became ready), if any.
