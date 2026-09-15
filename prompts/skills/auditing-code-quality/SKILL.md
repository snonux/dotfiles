---
name: auditing-code-quality
description: >
  Run a comprehensive code quality audit by orchestrating specialized skills
  for Go best practices, concrete defect hunting (find-code-bugs), SOLID
  principles, and system-level architecture, then create actionable tasks for
  the findings. Use when asked to "audit code quality", "full design review",
  "code health check", "architecture and code audit", or to combine design
  review with a bug sweep.
---

References are relative to /home/paul/.agents/skills/auditing-code-quality.

# Auditing Code Quality

Run a comprehensive code quality audit by invoking specialized skills in
sequence. This meta-skill orchestrates them so you only need a single command.

## Skills Invoked

1. **go-best-practices** — Go project structure, style, and conventions (loaded only when the target code is Go).
2. **100-go-mistakes** — 100 Go mistakes and how to avoid them (Go only).
3. **find-code-bugs** — Defect sweep (logic, concurrency, errors, APIs, security); **one `ask` task per confirmed bug** per that skill (all languages).
4. **solid-principles** — Class-level SOLID analysis (SRP, OCP, LSP, ISP, DIP).
5. **beyond-solid-principles** — System-level architecture principles (SoC, DRY, KISS, YAGNI, coupling, resilience, etc.).
6. **agent-task-management** — Creates actionable tasks for design/convention findings; bug tasks follow **find-code-bugs** + this skill's `ask` rules.
7. **audit-tagging** — Owns `audit/<date>` git markers; the **last** audit task created (workflow §6) tells the agent to follow that skill — do not duplicate its tagging procedure here.

## Workflow

### 1. Identify Target Code

Determine what code to analyze:
- When files or a directory are provided, use those.
- When a class, module, or service is referenced by name, locate it.
- When ambiguous, ask which files or directories to scan.

Detect the primary language(s) of the target code to decide whether to include
the Go-specific skill.

If the target is inside a git repo and this run does not already have an
explicit `$START_TAG` from the caller (e.g. **audit-next-repo** step 4), load
**audit-tagging** and follow its **Start tag** step now — always stamp a new
start tag for this run; collision `-N` handles same-day reuse. Do **not** skip
Start tag merely because some `audit/<date>` tag already exists on the repo
(prior audits, defer tags, and end markers are indistinguishable by name).
Capture the exact `$START_TAG` string (including any `-N` suffix) for the
tagging task in workflow §6. Do not push the start tag.

### 2. Load and Run Sub-Skills

Invoke each sub-skill using the `skill` tool:

If the target code is **Go**:

1. Load **go-best-practices** and run full audit on the code.
2. Load **100-go-mistakes** and run full audit on the code.

For **all** targets (Go or not):

3. Load **find-code-bugs** and run a full defect sweep on the same scope.
   Follow that skill end-to-end for **finding tasks only** (`ask add +bugfix`,
   annotations per **agent-task-management**). When instructing sub-agents or
   sub-skills, state explicitly: create remediation tasks for findings —
   **do not** create the ATM “Audit task batches” closure gate or tagging
   task; **auditing-code-quality** workflow §5–6 owns that close-out after
   **all** finding tasks (bugs + design) exist.

4. Load **solid-principles** and run a full SOLID audit on the target code.
5. Load **beyond-solid-principles** and run a full system-level audit on the
   same target code.

For each sub-skill, follow its own workflow (load references, analyze, report). Try to use sub-agents so each audit works with a fresh context. Even the sub-skills can spawn sub-agents themselves.

### 3. Produce a Unified Report

After all sub-skills have run, combine their findings into a single report:

#### Findings Table

```
| Category              | HIGH | MEDIUM | LOW |
|-----------------------|------|--------|-----|
| Bugs / defects        |      |        |     |
| SOLID                 |      |        |     |
| Architecture          |      |        |     |
| Go Best Practices     |      |        |     |
| **Total**             |      |        |     |
```

Count **Bugs / defects** from the **find-code-bugs** pass only (confirmed defects
with symptom + location). Leave **Go Best Practices** row empty or “N/A” when
the target is not Go.

#### Top 5 Priorities

List the five most impactful findings across all categories, ranked by severity
and practical impact. Prefer **critical/high defects** from **find-code-bugs**
when they exist. For each item, state the category, principle (or defect
type), location, and recommended action.

#### Overall Assessment

One paragraph summarizing the codebase's health: **defect risk** (from
**find-code-bugs**), then structural/design quality (class-level and
system-level). Note any tensions between principles (e.g., DRY vs. loose
coupling) and recommend a pragmatic path forward.

### 4. Create Tasks for Findings

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

### 5. Create the Audit-Closure Gate Task (mandatory)

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
**audit-tagging** and follow **End tag** + **Push the end marker remotely** on
that same `$START_TAG` (so a clean audit does not leave an unpushed local-only
start tag). Do not create a gate with an empty `depends:` list.

**Do not** create the gate or tagging task from **agent-task-management**'s
“Audit task batches” section during this run — this skill's §5–6 are the sole
owners when **auditing-code-quality** is driving.

### 6. Create the Audit-Marker Tagging Task (mandatory last task)

After the closure gate (workflow §5) exists, create **one last** task whose
only job is to stamp that this code audit was done on the git repo. That task
must **depend on the gate task** (so it stays blocked until every finding is
fixed and the gate has re-verified). Capture the gate's alias ID from
workflow §5, then:

```bash
ask add +audit depends:<gate-id> "Tag <project> that the code-quality audit is done: follow the audit-tagging skill to move the audit/<date> marker to the post-fix HEAD and push the end marker"
```

Tag it `+audit` (separate arg). Do **not** set a priority modifier. Annotate it
so a fresh-context agent can finish without re-deriving tagging rules:

- Exact `$START_TAG` string from workflow §1 / **audit-next-repo** (including
  any `-N` suffix). Do **not** recompute `audit/$(date +%F)` when the task
  later becomes READY — that would invent a different day's name.
- Load **audit-tagging** and follow its **End tag** + **Push the end marker
  remotely** sections to move that same name to the current (post-fix)
  `HEAD` and push it.
- Gate task ID it depends on; `ask list` must show that gate (and thus every
  finding) done before tagging.
- Cross-link only: **do not** paste `git tag` / `git push` incantations here —
  **audit-tagging** is the canonical home for naming, collision suffixes,
  start→end move, and push/protected-tag fallbacks.

This tagging task is the **last** task created for the audit batch and the
sole owner of the pushed end marker for this run. It resets `audit-due` churn
from the end of the fix cycle. Skip it only when workflow §5 was skipped.
