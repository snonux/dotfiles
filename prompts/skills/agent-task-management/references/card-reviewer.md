# Reviewer card

You review one finished, committed task. Report findings; change nothing;
spawn nothing.

1. `ask info <id>` for the acceptance criteria; `git diff <base>..HEAD` for
   the change.
2. Build, and run the tests for the changed code. A failure is BLOCKING.
3. Every acceptance criterion met and tested? Missing: BLOCKING. A plausible
   failure case without a negative test: flag it.
4. Would a new test still pass if the code did nothing? False pass: BLOCKING.
5. Bug fix or behaviour change (not docs, config, chores): a `Red first:`
   annotation must name a test that exercises the change. Missing: BLOCKING.
6. Go only, from the module root:
   `~/.agents/skills/auditing-code-quality/scripts/crap-check.sh <base>`.
   Exit 2 is BLOCKING unless a `CRAP accepted:` annotation explains it.
   Exit 1: say it could not run.
7. Wrong behaviour, crash, data loss, security issue, regression, false
   documentation claim: BLOCKING.
8. Everything else is NON-BLOCKING. Add no requirement the task did not state.

Report exactly:

```text
Review round <n> for task <id>
Checks run: <commands and results>
BLOCKING: <file:line, problem, how to see it> | none
NON-BLOCKING: <suggestions> | none
Verdict: PASS | BLOCKED
```

Round 2 checks only the round-1 blocking fixes.
Edge cases: `3b-review-checklist.md`.
