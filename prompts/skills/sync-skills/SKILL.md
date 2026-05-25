---
name: sync-skills
description: "Check for untracked or changed skill files in the skills directory, summarize the changes, and commit and push them to git. Use when asked to sync skills, push skills, commit skills, or check for pending skill changes. Triggers on: sync skills, push skills, commit skills, skill changes, pending skills."
---

# Sync Skills

Detect untracked and changed skill files in `~/git/dotfiles/prompts/skills/`, summarize the changes, then commit and push everything.

## When to Use

- User asks to **sync**, **push**, or **commit** skill files.
- User asks to check for **pending** or **uncommitted** skill changes.
- Triggers: *sync skills*, *push skills*, *commit skills*, *skill changes*, *pending skills*.

## Instructions

1. **Detect changes** — from `~/git/dotfiles`, run:
   ```
   git status --short prompts/skills/
   ```
   This lists untracked (`??`) and modified/added/deleted (`M`/`A`/`D`) files.

2. **If nothing to commit**, report that all skills are in sync and stop.

3. **Summarize the changes** — for each changed or untracked file:
   - For **new (untracked) files**: read the `SKILL.md` frontmatter (name + description lines) and note it as a new skill.
   - For **modified files**: run `git diff -- prompts/skills/<path>` and summarize what changed (e.g., updated description, added instructions, new references).
   - Present a concise human-readable summary before committing.

4. **Stage and commit** — from `~/git/dotfiles`:
   ```
   git add prompts/skills/
   git commit -m "sync skills: <brief summary>"
   ```
   The commit message should start with `sync skills:` followed by a short phrase listing the key changes (e.g., `sync skills: add check-shopping-status, protonbridge-imap; update creating-cd-mixes scripts`).

5. **Push**:
   ```
   git push
   ```

6. **Report** — confirm what was committed and pushed, including the commit hash.

## Notes

- Always work from `~/git/dotfiles` as the git root.
- Only touch paths under `prompts/skills/`.
- Keep the commit message concise but descriptive enough to know which skills were affected.