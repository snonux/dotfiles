# Reviewer card

Review one finished, committed task. Report findings; change and spawn
nothing. No code changed (audit, docs, chore, deploy): skip 2, 4–6; check the
deliverable against the task.

1. `ask info <id>` for the criteria; `git diff <base>..HEAD` for
   the change.
2. Build, lint, run the tests for the changed code. Failure: BLOCKING.
3. Every acceptance criterion met and tested? Missing: BLOCKING. Plausible
   failure case untested: flag it.
4. Would a new test pass if the code did nothing? False pass: BLOCKING.
5. Bug fix or behaviour change: a `Red first:` annotation names a test that
   exercises it. Refactor: its pinning tests passed before it and it did not
   edit them. Missing: BLOCKING.
6. Go only, from the module root:
   `~/.agents/skills/auditing-code-quality/scripts/crap-check.sh <base>`.
   Exit 2: BLOCKING unless `CRAP accepted:` is annotated. Exit 1: not run.
7. Wrong behaviour, crash, data loss, security issue, regression, false
   doc claim: BLOCKING.
8. Everything else: NON-BLOCKING. Add no requirement the task lacks.

Report exactly:

```text
Review round <n> for task <id>
Checks run: <commands and results>
BLOCKING: <file:line, problem, how to see it> | none
NON-BLOCKING: <suggestions> | none
Verdict: PASS | BLOCKED
```

Round 2: only the round-1 blocking fixes. More: `3b-review-checklist.md`.
