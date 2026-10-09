# Auditing Code Quality: tasks, closure gate and tagging task

Workflow §4–6 of [`SKILL.md`](../SKILL.md). The section numbers match the
workflow steps other skills refer to.

## 4. Create Tasks for Findings

**Bug tasks:** The **find-code-bugs** step should already have created **one
`ask` task per confirmed bug** (`+bugfix`, annotations per
**agent-task-management**). Do not merge multiple bugs into a single task. If
the repo had no git root, **find-code-bugs** lists findings without tasks —
note that in the report.

**Design and convention tasks:** After producing the unified report, load
**agent-task-management** and create a task for every **HIGH** and **MEDIUM**
severity finding from **solid-principles**, **beyond-solid-principles**, and
**(when Go)** **go-best-practices** / **100-go-mistakes** — not for bugs already
tracked above. Each such task should:

- Have a clear, actionable description (e.g., "Refactor UserService to fix SRP violation").
- Include the principle, category, and file location in an annotation.
- Be tagged with `+codequality` (separate arg, never quoted together with the description; `ask` rejects hyphens — do **not** use `+code-quality`).
- Set priority via the `priority:H`, `priority:M`, or `priority:L` modifier (separate arg).

**Exact command format** — keep each part as a separate argument, never quoted together:

```bash
ask add priority:H +codequality "Refactor UserService to fix SRP violation"
ask add priority:M +codequality "Fix high cognitive complexity in parser.go"
```

Do NOT do this (causes tag to land in description):
```bash
ask add "+codequality Fix foo"          # wrong: tag+desc quoted as one arg
ask add "+code-quality Fix foo"         # wrong: hyphenated tag rejected by ask
ask add "+codequality -p M Fix foo"     # wrong: everything in one quoted arg
```

## 5. Create the Audit-Closure Gate Task (mandatory)

After **all** audit tasks (bug tasks from **find-code-bugs** + design/convention
tasks from step 4) have been created, create one **gate task** that depends
on every one of them. This is the **verification** close-out only: it stays
blocked until every audit-driven task is done, then it re-verifies the
codebase. Completing the gate does **not** finish the git/`audit-due` marker —
workflow §6 still stamps that after the gate.

Collect every audit task alias ID created during this run (both the `+bugfix`
IDs and the `+codequality` IDs). Then create the gate task with all of them as
dependencies in a single `ask add`:

```bash
ask add +audit depends:<bug1>,<bug2>,...,<cq1>,<cq2>,... "Finalize <project> code-quality audit: verify all audit-driven fixes landed, re-run guardrails (build/vet/test -race/gofmt -l/linters), close out verification"
```

Tag it `+audit` (separate arg, never quoted with the description). Do **not** set
a priority modifier — its urgency is derived from its dependencies, and the
`depends:` list is what makes it a gate. Capture the printed alias ID and annotate
it with the closure checklist so a fresh-context agent can finish verification:

- The list of every dependent task ID and what it covers.
- The guardrail commands to re-run when this task becomes READY (the language's
  build/test/lint/gofmt-equivalents; for Go: `go build ./...`, `go vet ./...`,
  `go test -race ./...`, `gofmt -l .`, `errcheck ./...`).
- Instruction to confirm `ask list` shows every dependent done, then mark this
  gate done — and note that a separate tagging task (workflow §6) still owns
  the `audit/<date>` git marker afterward.

This gate is mandatory whenever any audit finding tasks were created. Skip the
gate **and** the tagging task in workflow §6 when there is no git root **or**
the audit produced no finding tasks (nothing to gate) — note that in the
report. When skipping because there were **zero findings** but a `$START_TAG`
was stamped for this run, still finalize the baseline now: load
**audit** (`references/tagging.md`) and follow **End tag** + **Push the end marker remotely** on
that same `$START_TAG` (so a clean audit does not leave an unpushed local-only
start tag). Do not create a gate with an empty `depends:` list.

**Do not** create the gate or tagging task from **agent-task-management**'s
“Audit task batches” section during this run — §5–6 of this skill are the sole
owners when **auditing-code-quality** is driving.

## 6. Create the Audit-Marker Tagging Task (mandatory last task)

After the closure gate (workflow §5) exists, create **one last** task whose
only job is to stamp that this code audit was done on the git repo. That task
must **depend on the gate task** (so it stays blocked until every finding is
fixed and the gate has re-verified). Capture the gate's alias ID from
workflow §5, then:

```bash
ask add +audit depends:<gate-id> "Tag <project> that the code-quality audit is done: follow the audit skill's tagging reference to move the audit/<date> marker to the post-fix HEAD and push the end marker"
```

Tag it `+audit` (separate arg). Do **not** set a priority modifier. Annotate it
so a fresh-context agent can finish without re-deriving tagging rules:

- Exact `$START_TAG` string from workflow §1 / **audit** (`references/next-repo.md`) (including
  any `-N` suffix). Do **not** recompute `audit/$(date +%F)` when the task
  later becomes READY — that would invent a different day's name.
- Load **audit** (`references/tagging.md`) and follow its **End tag** + **Push the end marker
  remotely** sections to move that same name to the current (post-fix)
  `HEAD` and push it.
- Gate task ID it depends on; `ask list` must show that gate (and thus every
  finding) done before tagging.
- Cross-link only: **do not** paste `git tag` / `git push` incantations here —
  **audit** (`references/tagging.md`) is the canonical home for naming, collision suffixes,
  start→end move, and push/protected-tag fallbacks.

This tagging task is the **last** task created for the audit batch and the
sole owner of the pushed end marker for this run. It resets `audit-due` churn
from the end of the fix cycle. Skip it only when workflow §5 was skipped.
