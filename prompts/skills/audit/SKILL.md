---
name: audit
description: "Schedules code audits across the git repos: picks the next repo due for an audit and manages the audit/<date> git tags that audit-due reads. Use when asked which repo to audit next or to tag, finalize, defer, or bootstrap an audit marker. Triggers on: audit next repo, next code audit, code audit due, run audit-due, audit tag, audit marker, defer audit."
---

# Audit

The audit cadence across `~/git/*`: which repo is due for a code audit next, and
the `audit/<date>` git tags that `~/scripts/audit-due` reads to measure churn
since the last audit. The audit itself is run by the
[`auditing-code-quality`](../auditing-code-quality/SKILL.md) skill.

## When to Use

- "Which repo should I audit next?", "audit next repo", "code audit due", "run audit-due"
- Tagging for a code audit: set the start marker, finalize or move the end marker, push it
- Deferring a repo from auditing, or bootstrapping a baseline tag on a repo that has none

## Reference Files

Load the one that matches the task:

- [Next repo](references/next-repo.md) — the entry point for an audit run: run `audit-due`, present the top 5 due repos with the stats that explain why, let the user pick one to audit or defer (never auto-audit), then hand over to `auditing-code-quality`; the permanently excluded repos; findings recorded as tasks in the audited repo
- [Tagging](references/tagging.md) — the canonical home for the `audit/<date>` markers: naming and same-day `-N` suffixes, the local-only start tag before an audit, the end tag moved to the post-fix `HEAD` and pushed, defer tags, bootstrapping a repo with no marker, and which caller stamps what

## Quick Reference

- `~/scripts/audit-due` lists due repos; `--json` for parsing, `--all` to include repos that are not due
- Start tag: `git tag "audit/$(date +%F)"` on the current `HEAD`, local only, before any audit work
- End tag: the same name moved to the post-fix `HEAD` and pushed, so the next run measures churn from the end of the fix cycle
- Next repo stamps the start tag; `auditing-code-quality` owns the delayed end tag through its final `+audit` task
