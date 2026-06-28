# Skill Best Practices (Agent Skills spec + pi)

Source: the [Agent Skills specification](https://agentskills.io/specification)
and pi's `docs/skills.md`. The rules below are what to enforce when auditing a
skill.

## Progressive disclosure (the core model)

Skills load progressively — take advantage of it:

| Layer | Loaded | Target size |
|-------|--------|-------------|
| Metadata | Always in context at startup | ~100 tokens (name + description) |
| Instructions | When the skill is activated (the full `SKILL.md` body) | **< 5000 tokens, < 500 lines** |
| Resources | On demand only (`scripts/`, `references/`, `assets/`) | As small as focused |

Keep `SKILL.md` under 500 lines. Move detailed reference material to separate
files so the activated body stays small.

## Frontmatter (required)

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | yes | 1-64 chars; lowercase a-z, 0-9, hyphens; no leading/trailing hyphen; no consecutive hyphens. Pi relaxes "must match parent dir" for shared skill dirs. |
| `description` | yes | 1-1024 chars; non-empty; what it does **and** when to use it. **Missing description ⇒ skill is not loaded.** |
| `license` | no | Short license name or bundled file reference. |
| `compatibility` | no | 1-500 chars; environment requirements (product, system packages, network). Most skills omit it. |
| `metadata` | no | Arbitrary string→string map; use reasonably unique keys. |
| `allowed-tools` | no | Space-separated pre-approved tools (experimental). |
| `disable-model-invocation` | no | `true` hides skill from system prompt; requires `/skill:name`. |

## Description best practices

The description determines when the agent loads the skill. Be specific and
include trigger keywords.

Good:
```yaml
description: Extracts text and tables from PDF files, fills PDF forms, and merges multiple PDFs. Use when working with PDF documents or when the user mentions PDFs, forms, or document extraction.
```

Poor:
```yaml
description: Helps with PDFs.
```

This collection's convention: end descriptions with `Triggers on: <comma-separated phrases>.`

## Structure

```
skill-name/
├── SKILL.md          # required: frontmatter + instructions
├── scripts/          # optional: executable code
├── references/       # optional: detailed docs loaded on demand
└── assets/           # optional: templates, images, data
```

Everything besides `SKILL.md` is freeform.

### scripts/

- Self-contained or document dependencies clearly
- Helpful error messages
- Handle edge cases gracefully
- Common languages: Python, Bash, JavaScript

### references/

- Detailed technical reference, form templates, domain-specific docs
- **Keep individual reference files focused** — agents load them on demand, so
  smaller files mean less context consumed
- One topic per file

## File references

Use relative paths from the skill root:

```markdown
See [the reference guide](references/REFERENCE.md) for details.
Run the extraction script: scripts/extract.py
```

Keep file references **one level deep** from `SKILL.md`. Avoid deeply nested
reference chains. (An index file like `references/storage.md` that links into
`references/storage/*.md` is acceptable but at the limit — prefer flat.)

## Validation

Pi validates skills against the Agent Skills standard. Most issues warn but
still load. **Exception: skills with missing `description` are not loaded.**
Name collisions (same name from different locations) warn and keep the first.

## Skill commands

Skills register as `/skill:name`. Arguments after the command are appended as
`User: <args>`. Toggle via `/settings` or `settings.json: { "enableSkillCommands": true }`.