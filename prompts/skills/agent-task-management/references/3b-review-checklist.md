# Review checklist

This file is all a review sub-agent needs. The orchestrator gives it to the
reviewer together with the task ID, the base commit, and the round number.
The rules for how reviews converge are in "Review budget and convergence" in
[3-complete-task.md](3-complete-task.md); the reviewer does not need to read them.

## Do these steps in order

1. Read the task: `ask info <id>`. Note its acceptance criteria.
2. Read the diff: `git diff <base-commit>..HEAD`.
3. Run the project's build and tests. A failure is **blocking**.
4. **Acceptance:** is every acceptance criterion met and tested? A missing
   test for a criterion is **blocking**.
5. **Return-nothing check:** for each new or changed test, ask: would it still
   pass if the code under test returned zero values or did nothing? If yes,
   it is a false pass: **blocking**. Tests that only assert on mocks or stubs
   fail this check.
6. **Red-first record:** for a bug fix or behaviour change, the task must have
   an annotation starting with `Red first:` that names a test, and that test
   must exercise the changed behaviour. Missing: **blocking**. (The fix is to
   show the test failing against the base commit, not to rewrite the change.)
   Documentation, configuration, and chore tasks are exempt.
7. **Negative tests:** where invalid input, an error path, or an unauthorized
   call is plausible, is there a test for it? If happy-path tests exist with
   no plausible negative test: flag it (blocking only when an acceptance
   criterion covers that failure case).
8. **Change risk (Go projects only):** from the module root run

   ```bash
   <skills-dir>/auditing-code-quality/scripts/crap-check.sh <base-commit>
   ```

   where `<skills-dir>` is the directory that contains `agent-task-management/`.
   - Exit 0: pass.
   - Exit 2: it lists functions at CRAP 30 or more that the change created or
     made more complex. Each is **blocking**, unless a task annotation starting
     with `CRAP accepted:` gives a reason (for example, a flat `switch`).
   - Exit 1 or the script is missing: say the check could not run. Not blocking.

   For other languages, skip this step unless the project documents an
   equivalent check.
9. **Correctness:** look for wrong behaviour, crashes, data loss, security
   issues, and regressions in the diff. Each is **blocking**.
10. Report using the format below. Do not spawn sub-agents. Do not add
    requirements the task did not state.

## What is blocking

Only these: a product defect; a false-pass test or a missing test for an
acceptance criterion; a build, lint, or test failure; a false documentation
claim; a missing `Red first:` record; an exit 2 from the change-risk check
without a `CRAP accepted:` annotation. Everything else (style, naming, wording,
extra hardening, hypothetical edge cases) is **non-blocking**.

## Report format

```text
Review round <1|2> for task <id>
Checks run: <commands and results; say which could not run>
BLOCKING:
- <file:line> <what is wrong> <how to see it>
NON-BLOCKING:
- <file:line> <suggestion>
Verdict: <PASS | BLOCKED>
```

Write `BLOCKING: none` when there are none. In round 2, check only that the
round-1 blocking findings are fixed and that the fix introduced no new
blocking defect.
