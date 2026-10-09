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
7. **audit** (`references/tagging.md`) — Owns `audit/<date>` git markers; the **last** audit task created (workflow §6) tells the agent to follow that skill — do not duplicate its tagging procedure here.

**go-best-practices** and **solid-principles** are manual-only skills
(`disable-model-invocation: true`), so the Skill tool will not invoke them.
Load them by reading [`../go-best-practices/SKILL.md`](../go-best-practices/SKILL.md)
and [`../solid-principles/SKILL.md`](../solid-principles/SKILL.md) directly, then
follow their reference links from there.

## Workflow

### 1. Identify Target Code

Determine what code to analyze:
- When files or a directory are provided, use those.
- When a class, module, or service is referenced by name, locate it.
- When ambiguous, ask which files or directories to scan.

Detect the primary language(s) of the target code to decide whether to include
the Go-specific skill.

If the target is inside a git repo and this run does not already have an
explicit `$START_TAG` from the caller (e.g. **audit** (`references/next-repo.md`) step 4), load
**audit** (`references/tagging.md`) and follow its **Start tag** step now — always stamp a new
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

After all sub-skills have run, combine their findings into one report: a
findings table by category and severity, the top 5 priorities, and an overall
assessment. Template and counting rules: [references/report.md](references/report.md).

### 4. Create Tasks for Findings

Bug tasks already exist from **find-code-bugs** (one per confirmed bug). Create a
`+codequality` task for every HIGH and MEDIUM design or convention finding.
Exact `ask add` format and what to annotate:
[references/tasks.md](references/tasks.md#4-create-tasks-for-findings).

### 5. Create the Audit-Closure Gate Task (mandatory)

One `+audit` gate task that depends on every finding task and re-verifies the
codebase once they are done. Skip rules and the zero-findings path:
[references/tasks.md](references/tasks.md#5-create-the-audit-closure-gate-task-mandatory).

### 6. Create the Audit-Marker Tagging Task (mandatory last task)

One last `+audit` task, depending on the gate, that moves the `audit/<date>`
marker to the post-fix `HEAD` and pushes it. Annotations it needs:
[references/tasks.md](references/tasks.md#6-create-the-audit-marker-tagging-task-mandatory-last-task).

§5–6 are the sole owners of the gate and tagging task when this skill is driving;
do not create them from **agent-task-management**'s "Audit task batches" section.
