---
name: solid-principles
description: >
  Review type and interface design using SOLID principles, reporting structural
  problems with demonstrable consequences. Use for class design audits, SOLID
  checks, or named principles such as SRP, LSP, and dependency inversion.
  Supports all five principles or a focused review of one.
metadata:
  version: "1.0.0"
---

# SOLID Principles

Use SOLID as lenses on type and interface design. Report problems with evidence
of concrete consequences, rather than seeking violations for every principle.

## Subcommands

Request a full audit or focus on a single principle:

| Command Pattern | Principle | Reference |
|----------------|-----------|-----------|
| `solid all` / `solid check` / `solid` | All five principles | Applicable references |
| `solid srp` | Single Responsibility | [srp.md](references/srp.md) |
| `solid ocp` | Open/Closed | [ocp.md](references/ocp.md) |
| `solid lsp` | Liskov Substitution | [lsp.md](references/lsp.md) |
| `solid isp` | Interface Segregation | [isp.md](references/isp.md) |
| `solid dip` | Dependency Inversion | [dip.md](references/dip.md) |

When no subcommand is specified, default to checking all five principles.
When a principle is mentioned by name (even without saying "solid"), match it to
the appropriate subcommand.

## Workflow

### 1. Identify Target Code

Determine what code to analyze:
- When files or a directory are provided, use those.
- When a class/module is referenced by name, locate it.
- When ambiguous, ask which files or directories to scan.

Supported languages: any OO language (Python, Java, TypeScript, C#, C++, Kotlin,
Go with struct methods, Rust with impl blocks, etc.). Adapt the principle checks
to the idioms of the target language — not every principle manifests identically
across languages.

### 2. Load Principle References

Read [the shared finding rules](../auditing-code-quality/references/report.md#shared-finding-rules)
for evidence, severity, deduplication, and advisory observations. They apply to
standalone reviews too. Read the relevant principle references from the table.
For `solid all`, consider all five and load those applicable to the target;
state which principles do not apply and why.

### 3. Analyze

Investigate applicable patterns in the code and its callers under the shared
rules. Check behavioral contracts, actual change patterns, and testability.
Reference heuristics do not establish a finding by themselves. Concrete
dependencies, switches, or large interfaces need a demonstrated consequence;
prefer a local fix when adding abstraction would cost more than it solves.

### 4. Report Findings

Use the shared finding format and severity rules. For a standalone review,
count each finding once under its primary principle, list up to three practical
priorities, and give a brief assessment. Separate advisory observations.
When part of a broader audit, return findings and evidence for its single
unified report; do not produce another full report or duplicate tracked bugs.

### 5. Refactor Mode (Optional)

When a fix or refactoring is requested (e.g., "fix this", "refactor it",
"show me the clean version"), produce refactored code that resolves the identified
problems. Explain each change briefly.

## Pragmatism Guidelines

These are guidelines, not laws. Apply judgment:

- Small utility scripts and prototypes get a lighter touch. Don't flag a 30-line
  script for lacking dependency injection.
- Some "violations" are conscious trade-offs. When a rationale is provided for
  a trade-off, acknowledge it rather than insisting on purity.
- Language idioms matter. A Python module with top-level functions isn't violating
  SRP just because it's not a class. Go interfaces are implicitly satisfied, so
  ISP looks different there.
- Prefer actionable findings over exhaustive catalogs. Five important findings
  beat twenty trivial ones.
