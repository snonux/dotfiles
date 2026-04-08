---
name: auditing-code-quality
description: >
  Full code quality audit combining SOLID principles, system-level architecture
  principles, and Go best practices. Use when asked to "audit code quality",
  "full design review", "check all principles", "code health check", or
  "architecture and code audit". Triggers on: audit, code quality, design review,
  full review, health check.
---

# Auditing Code Quality

Run a comprehensive code quality audit by invoking three specialized skills in
sequence. This meta-skill orchestrates them so you only need a single command.

## Skills Invoked

1. **go-best-practices** — Go project structure, style, and conventions (loaded only when the target code is Go).
2. **100-go-mistakes** — 100 Go mistakes and how to avoid them.
3. **solid-principles** — Class-level SOLID analysis (SRP, OCP, LSP, ISP, DIP).
4. **beyond-solid-principles** — System-level architecture principles (SoC, DRY, KISS, YAGNI, coupling, resilience, etc.).
5. **agent-task-management** — Creates actionable tasks for each finding that needs remediation.

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

For all targets, also if not **Go**:

3. Load **solid-principles** and run a full SOLID audit on the target code.
4. Load **beyond-solid-principles** and run a full system-level audit on the
   same target code.

For each sub-skill, follow its own workflow (load references, analyze, report). Try to use sub-agents so each audit works with a fresh context. Even the sub-skills can spawn sub-agents themselves.

### 3. Produce a Unified Report

After all sub-skills have run, combine their findings into a single report:

#### Findings Table

```
| Category              | HIGH | MEDIUM | LOW |
|-----------------------|------|--------|-----|
| SOLID                 |      |        |     |
| Architecture          |      |        |     |
| Go Best Practices     |      |        |     |
| **Total**             |      |        |     |
```

#### Top 5 Priorities

List the five most impactful findings across all categories, ranked by severity
and practical impact. For each, state the category, principle, location, and
recommended action.

#### Overall Assessment

One paragraph summarizing the codebase's structural health, covering both
class-level design and system-level architecture. Note any tensions between
principles (e.g., DRY vs. loose coupling) and recommend a pragmatic path
forward.

### 4. Create Tasks for Findings

After producing the unified report, load **agent-task-management** and
create a task for every HIGH and MEDIUM severity finding. Each task should:

- Have a clear, actionable description (e.g., "Refactor UserService to fix SRP violation").
- Include the principle, category, and file location in an annotation.
- Be tagged with `+code-quality` (separate arg, never quoted together with the description).
- Set priority via the `priority:H`, `priority:M`, or `priority:L` modifier (separate arg).

**Exact command format** — keep each part as a separate argument, never quoted together:

```bash
do add priority:H +code-quality "Refactor UserService to fix SRP violation"
do add priority:M +code-quality "Fix high cognitive complexity in parser.go"
```

Do NOT do this (causes tag to land in description):
```bash
do add "+code-quality Fix foo"          # wrong: tag+desc quoted as one arg
do add "+code-quality -p M Fix foo"     # wrong: everything in one quoted arg
```
