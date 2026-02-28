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

1. **solid-principles** — Class-level SOLID analysis (SRP, OCP, LSP, ISP, DIP).
2. **beyond-solid-principles** — System-level architecture principles (SoC, DRY, KISS, YAGNI, coupling, resilience, etc.).
3. **go-best-practices** — Go project structure, style, and conventions (loaded only when the target code is Go).
4. **taskwarrior-task-management** — Creates actionable tasks for each finding that needs remediation.

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

1. Load **solid-principles** and run a full SOLID audit on the target code.
2. Load **beyond-solid-principles** and run a full system-level audit on the
   same target code.
3. If the target code is **Go**, also load **go-best-practices** and check
   compliance with Go conventions.

For each sub-skill, follow its own workflow (load references, analyze, report).

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

After producing the unified report, load **taskwarrior-task-management** and
create a Taskwarrior task for every HIGH and MEDIUM severity finding. Each task
should:

- Have a clear, actionable description (e.g., "Refactor UserService to fix SRP violation").
- Include the principle, category, and file location in an annotation.
- Be tagged with `code-quality`.
- Use priority `H` for HIGH-severity findings and `M` for MEDIUM ones.

LOW-severity findings are noted in the report but do not get tasks unless the
user explicitly requests them.
