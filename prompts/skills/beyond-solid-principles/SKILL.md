---
name: beyond-solid-principles
description: "Finds structural problems with demonstrable consequences using system-level architecture principles, including simplicity, coupling, dependency direction, and resilience. Use when asked to check architecture principles, audit system design, or find coupling and architecture smells, all at once or one principle by name."
metadata:
  version: "1.0.0"
---

# Beyond SOLID — System-Level Architecture Principles

Analyze source code and system architecture for structural problems with demonstrable
consequences. Use the ten principles as investigation lenses, not a checklist that
must produce violations. Prioritize unnecessary complexity, coupling, dependency
direction, and failure propagation. Produce actionable findings with evidence,
severity ratings, locations, and proportionate remediation suggestions.

These principles operate at the architecture scale — modules, services, bounded
contexts, layers, APIs — complementing the class-level SOLID principles.

## Subcommands

Request a full audit or focus on a single principle:

| Command Pattern | Principle | Reference |
|----------------|-----------|-----------|
| `sw-soc` | Separation of Concerns | [soc.md](references/soc.md) |
| `sw-srp-sys` | Single Responsibility (system-level) | [srp-sys.md](references/srp-sys.md) |
| `sw-dry` | Don't Repeat Yourself (DRY) | [dry.md](references/dry.md) |
| `sw-demeter` | Law of Demeter / Principle of Least Knowledge | [demeter.md](references/demeter.md) |
| `sw-coupling` | Loose Coupling, High Cohesion | [coupling.md](references/coupling.md) |
| `sw-evolvability` | Build for Change (Evolvability) | [evolvability.md](references/evolvability.md) |
| `sw-resilience` | Design for Failure / Resilience | [resilience.md](references/resilience.md) |
| `sw-kiss` | KISS — Keep It Simple | [kiss.md](references/kiss.md) |
| `sw-pola` | Principle of Least Surprise (POLA) | [pola.md](references/pola.md) |
| `sw-yagni` | YAGNI at Architecture Level | [yagni.md](references/yagni.md) |
| `beyond-solid-principles` | All ten principles | Applicable references |

When no subcommand is specified, default to checking all ten principles.
When a principle is mentioned by name (even without the command prefix), match it to
the appropriate subcommand.

## Workflow

### 1. Identify Target Code

Determine what code or architecture to analyze:
- When files or a directory are provided, use those.
- When a service, module, or component is referenced by name, locate it.
- When ambiguous, ask which files, directories, or services to scan.

These principles apply to any language and any architecture style — monoliths,
modular monoliths, microservices, serverless, event-driven, layered, hexagonal, etc.
Adapt the principle checks to the idioms and scale of the target system.

For smaller codebases, focus on module/package boundaries, dependency direction,
and internal layering. For distributed systems, also consider service boundaries,
API contracts, data ownership, messaging patterns, and operational resilience.

### 2. Load Principle References

Read [the shared finding rules](../auditing-code-quality/references/report.md#shared-finding-rules)
for evidence, severity, deduplication, and advisory observations. They apply to
standalone reviews too. Read the relevant principle references from the table.
For a full audit, consider all ten and load those applicable to the target;
state which principles do not apply and why.

### 3. Analyze

For each target file, module, or service boundary, use the patterns from the loaded
references to investigate. The shared finding rules govern findings;
reference heuristics and remedies are candidates, not automatic diagnoses or fixes.
Consider current requirements, system scale, team size, and documented trade-offs.

Key analysis dimensions:
- **Static structure**: dependency direction, import graphs, layer boundaries.
- **Change patterns**: which files/modules change together (if VCS history is available).
- **Runtime topology**: service call chains, data flow, failure propagation paths.
- **API contracts**: consistency, encapsulation, versioning, naming conventions.
- **Operational posture**: timeouts, retries, circuit breakers, health checks.

### 4. Report Findings

Use the shared finding format and severity rules. For a standalone review,
count each finding once under its primary principle, list up to three practical
priorities, and give a brief assessment. Separate advisory observations.
When part of a broader audit, return findings and evidence for its single
unified report; do not produce another full report or duplicate tracked bugs.

### 5. Refactor Mode (Optional)

When a fix or refactoring is requested (e.g., "fix this", "refactor it",
"show me the clean version"), produce refactored code or an architecture proposal
that resolves the identified problems. Explain each change briefly.

## Pragmatism Guidelines

These are guidelines, not laws. Apply judgment:

- Small projects and prototypes get a lighter touch. Don't flag a weekend project
  for lacking circuit breakers or API versioning.
- Some "violations" are conscious trade-offs. When a rationale is documented (e.g.,
  in an ADR), acknowledge it rather than insisting on purity.
- Scale matters. A single-service CRUD app does not need the same architectural rigor
  as a platform serving millions of requests. Calibrate severity to context.
- Principles have productive tensions. DRY conflicts with loose coupling across service
  boundaries. KISS conflicts with resilience patterns. YAGNI conflicts with evolvability.
  Flag the tension and offer judgment, not dogma.
- Prefer actionable findings over exhaustive catalogs. Five important findings
  beat twenty trivial ones.
