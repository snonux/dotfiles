# Complete task

Use with `00-context.md`. Project name and global rules apply.

## Completion criteria (required before “done”)

A task is **not** considered done until all of the following are true:

- **Best practices** — the codebase (or changed parts) follows the project’s best practices.
- **Compilable** — all code compiles successfully (e.g. full build succeeds).
- **Tests pass** — all tests pass (e.g. full test suite green).

If any of these fail, fix the issues and recheck. Do not mark the task complete until they are all met.

## Before marking complete (after criteria are met)

**Once the completion criteria above are met:**

1. Spawn a **sub-agent** with **fresh context** (no prior conversation).
2. Sub-agent reviews the diff, code, or deliverables for the task and **reports back** to the main agent (review comments, suggestions, issues).
3. Main agent **addresses all review comments** from the sub-agent — no exceptions. Fix or respond to every point.
4. **After addressing comments, spawn another sub-agent** (fresh context again) to **review the code again** and confirm the fixes. If this second review finds further issues, address them and repeat the sub-agent review until the review is satisfied.
5. Only then:

```bash
task <id> done
```

## Conventions

- A task is not done until: best practices met, code compiles, all tests pass, all first-round review comments addressed, **and** a second sub-agent review has confirmed the code (or any further issues have been addressed and re-reviewed).
- Complete with `task <id> done` only after completion criteria, first review, addressing all comments, and the follow-up sub-agent review are satisfied.
- When completing a task, note which tasks were unblocked (dependents that became ready), if any.
