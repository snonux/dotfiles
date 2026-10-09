# Harness Compatibility

The skills directory is shared by several coding agents (`~/.agents/skills` and
`~/.claude/skills` point at the same tree). They do not agree on every
mechanism. Checked 2026-10-09 against the installed copies and the vendors'
docs; re-check before relying on a row, these tools change quickly.

## Manual-only skills

A manual-only skill is never auto-selected by the model and its description
stays out of the session context. It runs only when invoked by name.

| Harness | Mechanism | Explicit call |
|---------|-----------|---------------|
| Claude Code | `disable-model-invocation: true` in the `SKILL.md` frontmatter | `/skill-name` |
| pi | same frontmatter field | `/skill:name` |
| Cursor (editor and `cursor-agent`) | same frontmatter field | `/skill-name` |
| Codex | `agents/openai.yaml` in the skill directory with `policy.allow_implicit_invocation: false` | `$skill-name` |
| Amp | none per skill; only `amp.skills.disableClaudeCodeSkills` / `amp.skills.disableGlobalAgentsSkills` for whole sources | — |

So a manual-only skill in this collection carries **both** the frontmatter
line and the `agents/openai.yaml` file. Amp keeps listing it either way.

```yaml
# agents/openai.yaml
policy:
  allow_implicit_invocation: false
```

### When to make a skill manual-only

- **Good fit:** a skill the user always starts deliberately (burning a CD,
  purging a file from git history, a homelab reference loaded with `/f3s`).
- **Poor fit:** a skill other skills chain into, or one that should fire from a
  plain-language request. Once it is manual-only the Skill tool refuses it.
- **If a chained skill must be manual-only anyway:** every caller links to its
  `SKILL.md` or reference file by path (`../owner/SKILL.md`) and says to read
  it directly. A file read works regardless of the flag.

## What is always loaded

Only the `name` and `description` of each auto-loadable skill sit in every
session. Bodies and references load on demand in all five harnesses. That makes
description length the one recurring cost; see the description budget in
[best-practices.md](best-practices.md#description-budget).

## Lazy loading outside skills (instruction files)

| Harness | Loaded at start | Loaded on demand |
|---------|-----------------|------------------|
| Claude Code | `CLAUDE.md` in the working directory and above, `@path` imports, rules without `paths` | a subdirectory's `CLAUDE.md` when a file there is touched; `.claude/rules/*.md` with `paths:` frontmatter |
| Amp | `AGENTS.md` in the working directory, parents and `~/.config/amp/` | a subtree's `AGENTS.md`; `@`-mentioned files with `globs` frontmatter |
| Cursor | rules marked "Always Apply" | `.cursor/rules` set to "Apply Intelligently", "Apply to Specific Files" or "Apply Manually" |
| pi | `AGENTS.md` / `CLAUDE.md` from the agent directory, working directory and parents | nothing documented |
| Codex | `AGENTS.md` from the repo root down to the working directory (capped by `project_doc_max_bytes`) | nothing known |

Skills remain the only on-demand mechanism all five share, so knowledge that
should load lazily everywhere belongs in a skill, not in an instruction file.
