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
| `sw-soc` | Separation of Concerns | `references/soc.md` |
| `sw-srp-sys` | Single Responsibility (system-level) | `references/srp-sys.md` |
| `sw-dry` | Don't Repeat Yourself (DRY) | `references/dry.md` |
| `sw-demeter` | Law of Demeter / Principle of Least Knowledge | `references/demeter.md` |
| `sw-coupling` | Loose Coupling, High Cohesion | `references/coupling.md` |
| `sw-evolvability` | Build for Change (Evolvability) | `references/evolvability.md` |
| `sw-resilience` | Design for Failure / Resilience | `references/resilience.md` |
| `sw-kiss` | KISS — Keep It Simple | `references/kiss.md` |
| `sw-pola` | Principle of Least Surprise (POLA) | `references/pola.md` |
| `sw-yagni` | YAGNI at Architecture Level | `references/yagni.md` |
| `beyond-solid-principles` | All ten principles | All references |

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

Before analyzing, read the reference file(s) for the requested principle(s):

- [`references/soc.md`](references/soc.md) for Separation of Concerns
- [`references/srp-sys.md`](references/srp-sys.md) for Single Responsibility (system-level)
- [`references/dry.md`](references/dry.md) for DRY
- [`references/demeter.md`](references/demeter.md) for Law of Demeter
- [`references/coupling.md`](references/coupling.md) for Loose Coupling, High Cohesion
- [`references/evolvability.md`](references/evolvability.md) for Build for Change
- [`references/resilience.md`](references/resilience.md) for Design for Failure
- [`references/kiss.md`](references/kiss.md) for KISS
- [`references/pola.md`](references/pola.md) for Principle of Least Surprise
- [`references/yagni.md`](references/yagni.md) for YAGNI

For a full audit (`beyond-solid-principles`), read all ten.

### 3. Analyze

For each target file, module, or service boundary, use the patterns from the loaded
references to investigate. The evidence and pragmatism rules here govern findings;
reference heuristics and remedies are candidates, not automatic diagnoses or fixes.
Consider current requirements, system scale, team size, and documented trade-offs.

#### Evidence Required for Findings

For each finding, identify the affected behavior or supported change, cite the
relevant code, configuration, history, tests, or requirements, and explain the
causal link to the consequence. Valid evidence includes:

- A reachable failure path under the current design, even without a past incident.
  Trace effective deadlines, retry policies, and resource limits through callers
  and infrastructure before concluding that a safeguard is missing.
- Repeated maintenance pain supported by history or concrete examples, such as
  duplicated rules drifting or routine changes requiring coordinated deployments.
- A concrete supported change made difficult by the design. Cite the requirement
  and explain the extra edits, coordination, or regression exposure it creates.
- Unnecessary complexity with a demonstrable cost to an existing operation,
  maintenance activity, or supported change, and no compensating requirement.

Do not infer pain from file size, layer counts, folder layout, single-implementation
interfaces, or the absence of a named pattern alone. A hypothetical database swap,
traffic increase, or additional team is an advisory observation unless it is an
established requirement. Identify missing evidence rather than inventing it.

Merge overlapping symptoms of one underlying problem into one finding, citing all
relevant principles. Keep distinct failure paths or independently actionable problems
separate. When another audit pass already tracks the same defect, cross-reference it
instead of creating a second architecture finding or task.

Key analysis dimensions:
- **Static structure**: dependency direction, import graphs, layer boundaries.
- **Change patterns**: which files/modules change together (if VCS history is available).
- **Runtime topology**: service call chains, data flow, failure propagation paths.
- **API contracts**: consistency, encapsulation, versioning, naming conventions.
- **Operational posture**: timeouts, retries, circuit breakers, health checks.

### 4. Report Findings

Present findings using this structure:

#### Per Finding

```
**[PRIMARY PRINCIPLE] Finding — Severity: HIGH | MEDIUM | LOW**
Location: `filename` or `service/module`, lines ~XX-YY (if applicable)
Evidence: Specific code path, configuration, history, test, or supported requirement.
Consequence: How the structure causes a failure risk or concrete maintenance/change cost.
Related principles: Other lenses on this same problem, if applicable.
Suggestion: Smallest practical remedy, its trade-offs, and how to verify the improvement.
```

Severity guidelines:
- **HIGH**: Evidence shows material production risk, cascading failure, substantial
  active maintenance pain, or a blocked required change.
- **MEDIUM**: Evidence shows a bounded failure risk or recurring maintenance/change
  cost in current use or an established requirement; a concrete remedy is justified.
- **LOW**: Evidence supports a small practical improvement that is safe to defer.

Hypothetical growth concerns and unverified suspicions belong in a separate
**Advisory observations** section, with the condition or evidence that would justify
revisiting them. Give them no severity and do not create remediation tasks for them.

#### Summary

After all findings, provide:
- A count table: `| Principle | HIGH | MEDIUM | LOW |`; count each finding once
  under its primary principle, excluding advisory observations.
- Up to 3 priorities: which findings to fix first and why; do not fill a quota.
- Overall assessment: one paragraph on the system's structural health and
  evolvability posture.

### 5. Refactor Mode (Optional)

When a fix or refactoring is requested (e.g., "fix this", "refactor it",
"show me the clean version"), produce refactored code or an architecture proposal
that resolves the identified violations. Explain each change briefly.

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
- Prefer the smallest change that resolves the demonstrated consequence. Adding
  layers, interfaces, services, queues, or resilience patterns needs a concrete
  benefit that outweighs the complexity it introduces. Removing an abstraction
  also needs evidence; testability and isolation can justify a single implementation.

## Example Interaction

**User**: `sw-coupling` (with a codebase directory)

**Claude**:
1. Reads `references/coupling.md`
2. Analyzes the directory for coupling/cohesion violations
3. Reports evidence-supported findings with locations, consequences, severity,
   and proportionate suggestions; separates advisory observations
4. Provides a summary with priorities
