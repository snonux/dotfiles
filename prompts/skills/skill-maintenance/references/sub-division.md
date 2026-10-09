# Sub-division

When a skill grows too large, sub-divide it into a slim `SKILL.md` index plus
focused `references/`. The model in this collection is `f3s`: a short overview +
an area map + a tiny quick-reference in `SKILL.md`, one area index per subsystem
in `references/<area>.md`, and all detail in `references/<area>/<topic>.md`.

## When to sub-divide

Sub-divide when any of these hold:

- `SKILL.md` exceeds ~500 lines or ~5000 tokens (the spec's soft target).
- `SKILL.md` re-inlines content that already exists in its own `references/`
  (the worst DRY offender — the rocky VM skill, now `f3s/references/rocky-vm.md`, was this before refactoring).
- A single reference file covers multiple unrelated topics (split it).
- The agent would need to load the whole `SKILL.md` when only one section is
  relevant.

Do **not** sub-divide when:

- The skill is short (< ~110 lines) and cohesive.
- The inlined content *is* the skill's value and is needed the moment the
  skill activates (e.g. code snippets whose thresholds and code are
  inseparable; keep inline).
- The skill is a single linear procedure with no reusable sub-topics.

## The index pattern (f3s)

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
- A topic file that still grows past ~300 lines is split into sibling files in
  the same area folder (`garage.md`, `garage-commands.md`, `garage-clients.md`),
  not into a deeper folder; the area index groups them and names the one to
  start with.

## Folding related skills into one (f3s, audit, protonbridge)

Several small skills that share a subject cost one always-loaded description
each. Fold them into one skill when they are only ever used together or share a
canonical home: each former `SKILL.md` body becomes a reference (or an area
index), the surviving `SKILL.md` routes to them, and its description carries
the union of the trigger phrases. `f3s` absorbed the eight `f3s-*` skills plus
`miniflux-news`, `gogios`, `openwrt-router-management` and
`refresh-irregular-ninja`; `audit` absorbed `audit-next-repo` and
`audit-tagging`; `protonbridge` absorbed `protonbridge-aerc` and
`protonbridge-imap`. Other skills link to the reference file directly
(`../f3s/references/k3s.md`), which keeps working when the owning skill is
`disable-model-invocation: true`.

## Pitfalls when splitting a file

- **Positional prose breaks.** "See section 2", "§2a", "see above/below" and
  "this document" stop being true once the sections live in different files.
  Replace each with a link to the file that now holds the target, and drop
  section numbers from headings that are no longer referenced by number.
- **Headings other skills cite must stay put.** If other skills refer to
  "workflow §5–6" of a skill, keep those numbered headings in `SKILL.md` as
  short stubs that link to the reference (as `auditing-code-quality` does), or
  update every caller in the same change.
- **Anchored links need a per-part map.** A link to `old.md#some-heading` has to
  go to whichever part now contains that heading, not to the first part.
- **Shared intros.** A file's opening paragraphs often set context for all its
  sections; give each part the sentences it needs instead of leaving them all in
  the first part.

The full move procedure is in [moving-skills.md](moving-skills.md).

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
  `agent-task-management`, `llm-benchmark-comparison`, `music-collection`.
- **Sub-divided during the DRY pass:** the rocky VM skill (260 → ~40 line index, now an `f3s` area),
  `blog-writing-style` (216 → ~120 lines; examples moved to `references/`),
  `timesamurai` (272 → 85 lines), `auditing-code-quality` (220 → 107 lines; the
  numbered workflow headings stay in `SKILL.md` because other skills cite them).

## After sub-dividing

1. Confirm no information was lost (moved, not deleted).
2. Confirm every `SKILL.md` bullet links to an existing reference.
3. Confirm `SKILL.md` no longer duplicates any reference's content.
4. Confirm cross-skill links still resolve.