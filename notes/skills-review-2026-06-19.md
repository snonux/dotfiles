# Skills review — 2026-06-19 (task 5q0)

Reviewed all skills under `prompts/skills/` for DRY, clarity, and structure,
and broke up the most oversized monolithic `SKILL.md` files into a slim
`SKILL.md` + `references/` sub-files, matching the `f3s` /
`agent-task-management` pattern.

## Inventory (SKILL.md line counts, before this task)

Top flat skills *without* a `references/` dir (split candidates):

| Skill | Lines (before) | Action |
|---|---|---|
| blog-writing-style | 619 | **Split** → 216 |
| check-shopping-status | 319 | **Split** → 135 |
| photo-processing | 232 | **Split** → 155 |
| llm-benchmark-comparison | 225 | Follow-up task dq0 |
| music-collection | 217 | Follow-up task eq0 |
| c-best-practices | 187 | Follow-up task fq0 |

Everything else was ≤ 150 lines and reads coherently as a single file.

Already well-structured (slim SKILL.md + `references/`), left untouched:
`100-go-mistakes`, `agent-task-management`, `beyond-solid-principles`,
`f3s`, `persona`, `pkgrepo`, `rocky-vm-setup`, `solid-principles`.

Per the task brief, the just-restructured `agent-task-management`,
`go-best-practices`, and `f3s` were left alone.

## What changed (reorganization only — no content dropped)

### blog-writing-style (619 → 216)
- Extracted the large Wikipedia-based "Signs of AI writing" half into
  `references/signs-of-ai-writing.md` (voice calibration, personality/soul,
  the 29 numbered AI patterns with before/after examples, the full worked
  example, process/output format).
- SKILL.md keeps the foo.zone-specific de-LLM workflow plus a reference index
  and inline pointers to the deep catalog.

### check-shopping-status (319 → 135)
- Extracted `references/imap-scan-script.md` (the read-only Python one-shot
  script for steps 1–3) and `references/amazon-cdp.md` (the Chrome
  DevTools-Protocol login sequence + reusable Python helper).
- SKILL.md keeps the workflow prose, classification/carrier tables, status
  badges, and tips, with a reference index and inline links.

### photo-processing (232 → 155)
- Extracted the standalone ImageMagick auto-enhance tool into
  `references/auto-enhance.md` (`auto-enhance-photos.sh`, per-flag table,
  output naming, saturation tuning).
- SKILL.md keeps the dedup/burst/sharpness/staged-deletion culling workflow
  with a reference index.

All reference links verified to resolve to existing files.

## Follow-up tasks created

- `dq0` — split `llm-benchmark-comparison` (225 lines) into references/
- `eq0` — split `music-collection` (217 lines) into references/
- `fq0` — consider splitting `c-best-practices` (187 lines) into references/

## DRY / clarity notes

No cross-skill duplicated boilerplate worth deduplicating was found beyond the
expected, intentional cross-references (e.g. blog skills referencing each
other, check-shopping-status referencing protonbridge-imap). The SOLID /
beyond-solid / auditing-code-quality skills already delegate cleanly rather
than duplicating principle text.
