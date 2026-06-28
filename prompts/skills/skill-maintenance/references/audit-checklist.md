# Skill Audit Checklist

Step-by-step checklist for reviewing a single skill or sweeping the whole
`~/.agents/skills/` collection.

## Scope the sweep

```sh
# Skills changed in the last N months
find ~/.agents/skills -maxdepth 2 -name SKILL.md -newermt "-2 months" | sort

# Sizes — flag anything over ~500 lines or notably large
for f in ~/.agents/skills/*/SKILL.md; do printf "%5s %s\n" "$(wc -l < "$f")" "$f"; done | sort -rn
```

## Per-skill audit

### Frontmatter
- [ ] `name` present, 1-64 chars, lowercase a-z/0-9/hyphens, no leading/trailing/consecutive hyphens.
- [ ] `description` present, ≤1024 chars, states **what** and **when to use**, includes trigger keywords. (Missing ⇒ not loaded.)
- [ ] Optional fields (`license`, `compatibility`, `metadata`, `allowed-tools`, `disable-model-invocation`) used only when relevant.

### Structure / progressive disclosure
- [ ] `SKILL.md` < 500 lines / < 5000 tokens.
- [ ] `SKILL.md` does **not** re-inline content that exists in its own `references/` (the key DRY-within-skill check).
- [ ] Detail moved to `references/`; each reference file focused on one topic.
- [ ] File references one level deep; relative paths from skill root.
- [ ] Scripts self-contained, helpful errors, edge cases handled.

### DRY across skills
- [ ] Identify shared knowledge (snippets, conventions, discipline) used by >1 skill.
- [ ] Each piece of shared knowledge has exactly **one canonical home**.
- [ ] Consumers cross-link (`../owner/SKILL.md` or `../owner/references/x.md`) instead of duplicating.
- [ ] Prerequisites declared up front in the consumer's `SKILL.md`.
- [ ] No two skills silently own the same knowledge (conflict ⇒ surface to user with a recommendation).

### Links
- [ ] All internal links resolve. Verify:
  ```sh
  for l in $(grep -roh '\.\./[A-Za-z0-9_./-]*\.md' skill/SKILL.md skill/references/*.md); do
    test -f "skill/$l" || echo "MISS skill/$l"
  done
  ```
- [ ] Cross-skill links use `../sibling/...` and resolve.

### Description / discovery
- [ ] Description would cause the agent to load the skill for the intended tasks (specific keywords, "when to use").
- [ ] No duplicate `name` across locations (collisions warn; first wins).

## Sweep workflow

1. List changed skills (scope).
2. For each, run the per-skill audit; record findings.
3. Group findings: spec violations, sub-division candidates, DRY candidates, link breakage.
4. For DRY ownership conflicts, prepare a recommendation per [dry-across-skills.md](dry-across-skills.md) and **surface to the user** — do not silently decide.
5. Present the plan with proposed refactors and the conflicts requiring decisions.
6. After approval, apply edits (move, don't delete); re-verify links and "no SKILL.md duplicates its references".
7. Commit/sync via the `commit-skills` skill from `~/git/dotfiles`.

## Health quick-stat (whole collection)

```sh
# Largest SKILL.md files
for f in ~/.agents/skills/*/SKILL.md; do printf "%5s %s\n" "$(wc -l < "$f")" "$f"; done | sort -rn | head

# Skills without a description (would not load) — empty output = healthy
for f in ~/.agents/skills/*/SKILL.md; do
  awk '/^---$/{c++; next} c==1 && /^description:/{print FILENAME; found=1} c==2{exit}' "$f" | grep -q . || echo "NO DESCRIPTION: $f"
done

# Cross-skill link check (relative ../ links)
for d in ~/.agents/skills/*/; do
  for l in $(grep -roh '\.\./[A-Za-z0-9_./-]*\.md' "$d/SKILL.md" "$d"references/*.md 2>/dev/null); do
    target="$(dirname "$d/SKILL.md")/$l"
    test -f "$target" || echo "MISS ($d): $l -> $target"
  done
done
```