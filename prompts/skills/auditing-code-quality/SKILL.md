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

## Workflow

### 1. Identify Target Code

Determine what code to analyze:
- When files or a directory are provided, use those.
- When a class, module, or service is referenced by name, locate it.
- When ambiguous, ask which files or directories to scan.

Detect the primary language(s) of the target code to decide whether to include
the Go-specific skill.

### 2. Load and Run Sub-Skills

Invoke each sub-skill using the `skill` tool:

If the target code is **Go**:

1. Load **go-best-practices** and run full audit on the code.
2. Load **100-go-mistakes** and run full audit on the code.

For **all** targets (Go or not):

3. Load **find-code-bugs** and run a full defect sweep on the same scope.
   Follow that skill end-to-end, including **one remediation task per distinct
   confirmed bug** (`ask add +bugfix`, annotations per **agent-task-management**).

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
- Be tagged with `+code-quality` (separate arg, never quoted together with the description).
- Set priority via the `priority:H`, `priority:M`, or `priority:L` modifier (separate arg).

**Exact command format** — keep each part as a separate argument, never quoted together:

```bash
ask add priority:H +code-quality "Refactor UserService to fix SRP violation"
ask add priority:M +code-quality "Fix high cognitive complexity in parser.go"
```

Do NOT do this (causes tag to land in description):
```bash
ask add "+code-quality Fix foo"          # wrong: tag+desc quoted as one arg
ask add "+code-quality -p M Fix foo"     # wrong: everything in one quoted arg
```
