# Sub-division

When a skill grows too large, sub-divide it into a slim `SKILL.md` index plus
focused `references/`. The model in this collection is `f3s` and
`f3s-rocky-vm-setup`: a short overview + a "Reference Files" list + a tiny
quick-reference, with all detail living in `references/*.md`.

## When to sub-divide

Sub-divide when any of these hold:

- `SKILL.md` exceeds ~500 lines or ~5000 tokens (the spec's soft target).
- `SKILL.md` re-inlines content that already exists in its own `references/`
  (the worst DRY offender — `f3s-rocky-vm-setup` was this before refactoring).
- A single reference file covers multiple unrelated topics (split it).
- The agent would need to load the whole `SKILL.md` when only one section is
  relevant.

Do **not** sub-divide when:

- The skill is short (< ~110 lines) and cohesive.
- The inlined content *is* the skill's value and is needed the moment the
  skill activates (e.g. the aHash/burst/sharpness snippets in `photo-processing`
  — thresholds and code are inseparable; keep inline).
- The skill is a single linear procedure with no reusable sub-topics.

## The index pattern (f3s / f3s-rocky-vm-setup)

A sub-divided `SKILL.md` should contain:

1. Frontmatter (unchanged).
2. One-paragraph overview (what the skill covers, the system's role).
3. **When to Use** — triggers.
4. **Reference Files** — a bullet list, one line each, linking to
   `references/<file>.md` with a short "covers …" clause. This is the map.
5. **Quick Reference** — the handful of facts needed without loading a
   reference (IPs, key commands, one-line summaries). Optional.

Everything else moves to `references/`. The `SKILL.md` becomes a router: the
agent loads the one reference that matches the task.

## Naming and sizing reference files

- One topic per file. If a file would cover two unrelated topics, split it.
- Name files by topic: `hardware.md`, `freebsd-setup.md`, `wireguard.md`,
  `tmux.md`, `tools.md`. Not by number (except lifecycle-ordered skills like
  `agent-task-management` where `1-create-task.md` … `6-recover-…` reflects a
  sequence).
- A reference that itself grows large can become an *index* into a subfolder:
  `references/storage.md` → `references/storage/zfs.md`,
  `references/storage/zrepl.md`. Keep this to one level of nesting.

## The "must not duplicate its own references" rule

The clearest sub-division signal: `SKILL.md` contains a table/block that also
exists verbatim in `references/<file>.md`. Fix it by removing the inlined copy
from `SKILL.md` and keeping only the index entry. Verify with:

```sh
# nothing in SKILL.md should appear verbatim in a reference
grep -l "<unique line from SKILL.md>" skill/references/*.md
```

## Sub-division in this collection (status)

- **Good index models:** `f3s`, `c-best-practices`, `bash-best-practices`,
  `agent-task-management`, `llm-benchmark-comparison`, `music-collection`,
  `f3s-rocky-vm-setup` (after refactor).
- **Sub-divided during the DRY pass:** `f3s-rocky-vm-setup` (260 → ~40 line index),
  `blog-writing-style` (216 → ~120 lines; examples moved to `references/`).
- **Borderline, kept inline by design:** `photo-processing` (snippets are the
  skill's value), `check-shopping-status` (already delegates to 2 refs).

## After sub-dividing

1. Confirm no information was lost (moved, not deleted).
2. Confirm every `SKILL.md` bullet links to an existing reference.
3. Confirm `SKILL.md` no longer duplicates any reference's content.
4. Confirm cross-skill links still resolve.