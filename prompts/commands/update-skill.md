# /update-skill

**Description:** Guide me step-by-step to update an existing skill in ~/Notes/Prompts/skills/. Help me modify the description, instructions, or any other aspect of the skill.

**Parameters:**
- skill_name: The name of the existing skill to update (e.g., "go-best-practices", "compose-blog-post")

**Example usage:**
- `/update-skill go-best-practices`
- `/update-skill compose-blog-post`

---

## Prompt

I need to update an existing skill. Please follow these steps:

1. **Read the existing skill file** from `~/Notes/Prompts/skills/{{skill_name}}/SKILL.md`
   - If the file doesn't exist, inform me and list available skills in the skills directory

2. **Show me the current content** of the skill in a clear, organized format

3. **Audit it against the collection's conventions** — load the `skill-maintenance` skill and run its `references/audit-checklist.md` against this skill. Surface findings before editing:
   - *best-practices*: frontmatter valid (`name`/`description` rules, `description` ≤1024 with trigger keywords), `SKILL.md` < 500 lines, file refs one level deep, no missing `description`.
   - *dry-across-skills*: does this skill duplicate knowledge another skill owns? Should shared knowledge get a single canonical home with cross-links instead?
   - *sub-division*: does `SKILL.md` re-inline content that already lives in its own `references/`? Should detail move to focused `references/` so `SKILL.md` becomes a slim index?
   - Broken internal / cross-skill links.
   Present the audit findings alongside the content; let the user decide what to fix (do not silently refactor).

4. **Ask me what I want to update** using the AskUserQuestion tool:
   - Description (YAML frontmatter)
   - When to Use section
   - Instructions
   - All of the above

5. **Guide me through the updates** interactively:
   - For description: Ask for the new description
   - For When to Use: Ask what triggers should be added or changed
   - For instructions: Ask for the new content or specific sections to change

6. **Show me a preview** of the updated skill before saving

7. **Save the updated skill** back to `~/Notes/Prompts/skills/{{skill_name}}/SKILL.md`

8. **Confirm** the update was successful and summarize what changed

Be helpful and thorough - make sure I understand each change and why it improves the skill.
