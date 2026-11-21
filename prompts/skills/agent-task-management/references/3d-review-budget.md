# Review budget, batch reviews, and skipping reviews

Read this when a review reports blocking findings a second time, when the
user asks for fewer or no reviews, or when you are unsure whether a finding
is blocking. The reviewer's own steps are in
[card-reviewer.md](card-reviewer.md).

## Review budget and convergence

Reviews must converge. An open-ended "find every flaw until a review is clean" loop never terminates: each round finds smaller issues, and every round costs a rebuild and test run. Follow these rules unless the user or the task explicitly asks for more:

- **At most two review rounds per task**: one full review, and a second, narrow confirmation round only when the first found blocking issues.
- **Blocking** means one of:
  - a product defect: wrong behaviour, a crash, data loss, a security issue, a regression;
  - a test or oracle that can pass while the behaviour is wrong (a false pass), or a missing test for an acceptance criterion;
  - a build, lint or test failure;
  - a missing `Red first:` record, or a failed change-risk check without a `CRAP accepted:` annotation (both defined in [3b-review-checklist.md](3b-review-checklist.md));
  - a documentation claim that is false about what the product does or what was verified.
- **Non-blocking** means everything else: wording, style, naming, extra hardening, nicer diagnostics, additional evidence or provenance records, duplicated helpers, hypothetical edge cases outside the acceptance criteria. Fix it inline if cheap, otherwise drop it or create a follow-up task. It never triggers another round.
- **Do not raise the bar mid-task.** Neither the orchestrator nor the reviewer adds requirements the task did not state (for example identity hashes, evidence sha256 tables, clause-to-test tables, negative-control suites). If such a requirement is worth having, create a separate task for it.
- **Out-of-scope discoveries** (bugs in other areas, shared helpers, flaky unrelated tests) become new tasks with full context; they do not extend the current task's review.
- Tell every reviewer these rules in its prompt, including the round number and that it must classify each finding.

## Batch reviews (only when the user asks)

The default is one review per task. When the user asks for batch reviews
(for example "review everything at the end", or `review=batch` on
work-on-tasks), close each task after its self-review, its checks, and its
commit, without a reviewer. Then run **one** reviewer over the combined diff
at the end of the milestone, or after every ten tasks, whichever comes first.
Give it [card-reviewer.md](card-reviewer.md) and the list of task IDs.
Blocking findings become new `+bugfix` tasks with full context; they do not
reopen the closed tasks. Record the mode on each task:

```bash
ask annotate <id> "Review skipped: batch review requested by user."
```

Batch mode suits many small, low-risk tasks in one area. Keep per-task
reviews for security-sensitive changes, data migrations, and anything that
is hard to undo, even in batch mode.

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
  test quality, so apply [card-reviewer.md](card-reviewer.md) to your own work.
- **The user's request overrides the "sub-agent reviews pass" wording** that
  older tasks still carry in their "Agent workflow" annotation.
- **Scope it as the user stated it** — a single task, the current batch, or the
  rest of the session. If the scope is unstated, apply it to the tasks worked on
  under the current request. It does not carry over to later sessions.
- **Record it in an annotation** so the task history is honest:

  ```bash
  ask annotate <id> "Review skipped: user request; self-review only."
  ```
