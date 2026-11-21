# Auditing Code Quality: unified report

Shared finding rules for all design/convention reviews, including standalone
SOLID and beyond-SOLID reviews. Workflow §3 of [`SKILL.md`](../SKILL.md) uses
the unified report format below after all three passes.

## Shared Finding Rules

For each design or convention finding, cite the code, configuration, history,
test, or established requirement and explain how it causes a concrete failure
risk, maintenance cost, difficulty with a supported change, or violation of a
project requirement. Recommend the smallest practical remedy and how to verify
it. Principle names alone do not justify findings.

Valid evidence includes a reachable failure path (no past incident required),
repeated maintenance pain supported by history or concrete examples, a supported
change made difficult by the design, or unnecessary complexity with a demonstrated
cost and no compensating requirement. Trace effective safeguards through callers
and infrastructure before claiming that deadlines, retries, or resource limits
are missing. Identify missing evidence rather than inventing it.

File size, layer or method counts, folder layout, coverage percentages,
single-implementation interfaces, and absence of a named pattern are investigation
signals, not findings on their own. Cite the actual requirement and impact for
convention findings; local preferences do not make code defective.
Complexity, duplication, and mutation scores likewise direct attention to code;
they do not establish a defect without a failing behavior or concrete cost.
A surviving mutant does show a concrete cost when the behaviour it changes
matters: a regression there would ship undetected. Name that behaviour in the
finding, not the score ([metrics.md](metrics.md#3-test-quality-pass-c)).

Use these severity levels for design and convention findings:

- **HIGH**: Material production risk, cascading failure, substantial active
  maintenance pain, or a blocked required change.
- **MEDIUM**: Bounded failure risk or recurring maintenance/change cost in
  current use or an established requirement, with a justified concrete remedy.
- **LOW**: A small practical improvement supported by evidence, safe to defer.

Defects retain **find-code-bugs** severity levels, including CRITICAL where
appropriate. Establish the symptom/failure mode and location before filing a bug,
regardless of which pass found it.

Merge findings that describe the same underlying problem across principles or
passes. Assign one primary category and retain related principles as context.
If a confirmed bug already covers the problem, count it under **Bugs / defects**
only and reuse its existing task. Keep distinct confirmed bugs separate.

Put hypothetical growth concerns and unverified suspicions in **Advisory
observations**, with the condition or evidence needed to revisit them. They have
no severity, do not count as findings, and generate no remediation tasks.

Choose the smallest practical remedy and state how to verify it. Both adding
and removing abstractions need a benefit that outweighs their cost; testability,
isolation, and stable contracts can justify an interface with one implementation.
Reference heuristics and remedies do not override these rules.
Prefer a test that enters through the affected public boundary and checks an
observable result. If a faithful automated test is impractical, name the
manual or integration check instead of adding a test that merely mirrors the
implementation. For repeated failures, address the common cause rather than
filing separate tasks for each symptom. When the same violation or pattern
recurs at many sites, the remedy is a lever: one lint rule, analyzer, or
codemod that fixes the sites and keeps them fixed, filed as one finding.
A problem that an earlier audit already fixed and that has come back is one
finding about why it recurs, not another local fix.

### Finding Format

```text
Title / primary category or principle / severity
Location: file + symbol/line, or module/service boundary
Evidence: code path, configuration, history, test, or established requirement
Consequence: causal link to the failure risk or maintenance/change cost
Related principles: other lenses on the same problem, if useful
Remedy and verification: smallest practical fix, trade-offs, expected outcome
Task ID: when a remediation task has been created
```

## Unified Report

State the reviewed scope and summarize checks that passed, failed, or could not
run. Separate verified findings from advisory observations; do not imply that
unrun checks passed.

### Findings Table

```
| Category              | CRITICAL | HIGH | MEDIUM | LOW |
|-----------------------|----------|------|--------|-----|
| Bugs / defects        |          |      |        |     |
| Design / architecture | N/A      |      |        |     |
| Conventions           | N/A      |      |        |     |
| **Total**             |          |      |        |     |
```

Count confirmed defects discovered in any pass under **Bugs / defects**, using
**find-code-bugs** classification and task rules. Count each distinct finding
once in its primary category; principle names remain context, not separate rows.

### Hotspots

The pass A ranking from [metrics.md](metrics.md#1-hotspot-ranking-pass-a):
the top 10 rows, plus any row a finding refers to, with the finding or task ID
next to it. Also list the duplication, dead-code, and mutation commands with
their headline results (for example, "gremlins on ./internal/store: 41 killed,
6 lived, 3 not covered"). A hotspot with no finding next to it is fine. It
means the code was read and judged acceptable, so say that rather than
inventing a finding.

```
| CRAP  | CC | COV% | Location              | Func         | Finding / task |
|-------|----|------|-----------------------|--------------|----------------|
| 240.0 | 15 | 0    | cmd/x/main.go:222     | runWatchMode | 3 / task 12    |
```

### Top 5 Priorities

List up to five impactful findings across all categories, ranked by severity
and practical impact. Prefer **critical/high defects** from **find-code-bugs**
when they exist. For each item, state the category, principle (or defect
type), location, and recommended action.
Do not fill the list with advisory observations to reach five items.

### Overall Assessment

One paragraph summarizing the codebase's health: **defect risk** (from
**find-code-bugs**), then structural/design quality (class-level and
system-level). Note any tensions between principles (e.g., DRY vs. loose
coupling) and recommend a pragmatic path forward.
