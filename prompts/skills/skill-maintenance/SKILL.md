---
name: skill-maintenance
description: "Maintain the ~/.agents/skills collection: audit skills against the Agent Skills spec, keep knowledge DRY across skills, sub-divide or fold skills for progressive loading, rename or delete skills safely, and manage manual-only skills across harnesses. Use when asked to review, refactor, audit, move, or health-check skills. Triggers on: skill maintenance, audit skills, review skills, refactor skills, skill health, DRY skills, sub-divide skill, fold skills, rename skill, manual-only skill, skill best practices."
disable-model-invocation: true
---

# Skill Maintenance

Maintain the `~/.agents/skills/` collection: keep each skill compliant with the
[Agent Skills spec](https://agentskills.io/specification), DRY across skills,
and sub-divided so `SKILL.md` stays a slim index (progressive disclosure).

## When to Use

- Audit one skill or the whole collection for spec compliance and health
- Refactor a skill that has grown too large or duplicated content
- Review whether shared knowledge has a single canonical home (DRY)
- Sub-divide a skill whose `SKILL.md` re-inlines its own `references/`
- Commit and sync skill changes (delegates to `commit-skills`)

## Reference Files

Detailed reference documentation is in the `references/` subfolder:

- [Best Practices](references/best-practices.md) — the Agent Skills spec rules + pi specifics: progressive disclosure (metadata ~100 tokens always loaded; instructions <5000 tokens / <500 lines; resources on demand), frontmatter, name rules, description, structure, scripts, references, file refs one level deep, validation.
- [DRY Across Skills](references/dry-across-skills.md) — DRY principles for a skill collection: one canonical home for shared knowledge; cross-link via `../sibling/SKILL.md`; when to share a reference vs. keep a skill self-contained; how to resolve conflicts; worked examples from this collection.
- [Sub-division](references/sub-division.md) — when and how to sub-divide an oversized skill into focused `references/`: the index pattern (`f3s`: area indexes + topic files), folding related skills into one, the "SKILL.md must not duplicate its own references" rule, naming and sizing reference files, keeping refs one level deep.
- [Audit Checklist](references/audit-checklist.md) — the concrete step-by-step checklist for reviewing a single skill or sweeping the whole collection.
- [Moving Skills](references/moving-skills.md) — renaming, folding or deleting a skill: where else it is referenced (commands, `sharable.md`, fish config, the conf repo), relinking by script, prose that links cannot fix, carrying triggers over, proving nothing was lost.
- [Harness Compatibility](references/harness-compat.md) — which agent honours what: manual-only skills (frontmatter flag for Claude Code, pi and Cursor; `agents/openai.yaml` for Codex; nothing per skill for Amp), when to make a skill manual-only, and lazy loading of instruction files per harness.

## Scripts

- `scripts/audit_skills.py` — the mechanical sweep: `python3 scripts/audit_skills.py --extra ../commands [--gone <old-name> ...]`. Exits 1 on spec violations or broken links; warnings are judgment calls.

## Quick Checklist

- [ ] `SKILL.md` < 500 lines / < 5000 tokens; detail moved to `references/`
- [ ] `SKILL.md` does not re-inline content already in its own `references/`
- [ ] Each reference file is focused (one topic); refs one level deep, or one area index deeper for a large skill
- [ ] Frontmatter valid: `name` (lowercase, hyphens, ≤64), `description` (≤1024, specific keywords + when-to-use)
- [ ] `description` includes trigger phrases so the agent loads it on match, and stays near 300 characters
- [ ] Manual-only skills carry both `disable-model-invocation: true` and `agents/openai.yaml`; callers link to them by path
- [ ] File references use relative paths from the skill root
- [ ] Shared knowledge has exactly one canonical home; others cross-link, don't duplicate
- [ ] Cross-skill links resolve: `../sibling/SKILL.md` or `../sibling/references/x.md`
- [ ] Scripts self-contained, helpful errors, edge cases handled
- [ ] No spec warnings (run `pi` validation; missing `description` = not loaded)

## Workflow

1. **Scope.** Confirm which skills to review (e.g. changed in the last N months: `find ~/.agents/skills -name SKILL.md -newermt "-N months"`).
2. **Audit.** Run `scripts/audit_skills.py`, then load [references/audit-checklist.md](references/audit-checklist.md) and apply the non-mechanical items per skill. Record findings.
3. **DRY.** Load [references/dry-across-skills.md](references/dry-across-skills.md); identify duplicated knowledge and propose a single canonical home. **Surface conflicts to the user before changing skills** — do not silently decide ownership disputes.
4. **Sub-divide.** Load [references/sub-division.md](references/sub-division.md); split oversized `SKILL.md`s into an index + focused references.
5. **Decide.** Present the plan; get approval on conflicts before editing.
6. **Refactor.** Apply edits; preserve all information (move, don't delete). For renames, folds and deletions follow [references/moving-skills.md](references/moving-skills.md).
7. **Verify.** Re-run `scripts/audit_skills.py` until it reports no errors.
8. **Commit.** Use the `commit-skills` skill to summarize and push changes.