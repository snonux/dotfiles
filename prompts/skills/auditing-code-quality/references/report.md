# Auditing Code Quality: unified report

Workflow §3 of [`SKILL.md`](../SKILL.md): the report produced after all
sub-skills have run.


After all sub-skills have run, combine their findings into a single report:

## Evidence and Deduplication

For each design or convention finding, cite the code, configuration, history,
test, or established requirement and explain how it causes a concrete failure
risk, maintenance cost, difficulty with a supported change, or violation of a
project requirement. Recommend the smallest practical remedy and how to verify
it. Principle names alone do not justify findings.

Merge findings that describe the same underlying problem across principles or
passes. Assign one primary category and retain related principles as context.
If a confirmed bug already covers the problem, count it under **Bugs / defects**
only and reuse its existing task. Keep distinct confirmed bugs separate.

Put hypothetical growth concerns and unverified suspicions in **Advisory
observations**, with the condition or evidence needed to revisit them. They have
no severity, do not count as findings, and generate no remediation tasks.

## Findings Table

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
the target is not Go. Count each distinct finding once in its primary category.

## Top 5 Priorities

List up to five impactful findings across all categories, ranked by severity
and practical impact. Prefer **critical/high defects** from **find-code-bugs**
when they exist. For each item, state the category, principle (or defect
type), location, and recommended action.
Do not fill the list with advisory observations to reach five items.

## Overall Assessment

One paragraph summarizing the codebase's health: **defect risk** (from
**find-code-bugs**), then structural/design quality (class-level and
system-level). Note any tensions between principles (e.g., DRY vs. loose
coupling) and recommend a pragmatic path forward.
