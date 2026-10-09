# Auditing Code Quality: unified report

Workflow §3 of [`SKILL.md`](../SKILL.md): the report produced after all
sub-skills have run.


After all sub-skills have run, combine their findings into a single report:

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
the target is not Go.

## Top 5 Priorities

List the five most impactful findings across all categories, ranked by severity
and practical impact. Prefer **critical/high defects** from **find-code-bugs**
when they exist. For each item, state the category, principle (or defect
type), location, and recommended action.

## Overall Assessment

One paragraph summarizing the codebase's health: **defect risk** (from
**find-code-bugs**), then structural/design quality (class-level and
system-level). Note any tensions between principles (e.g., DRY vs. loose
coupling) and recommend a pragmatic path forward.
