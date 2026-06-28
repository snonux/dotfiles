# /create-skill

**Description:** Create a new skill by inferring its purpose from the skill name. The skill will be saved to ~/Notes/Prompts/skills/<skill-name>/SKILL.md with proper YAML frontmatter.

**Parameters:**
- skill_name: The name of the new skill to create (e.g., "go-best-practices", "docker-compose", "rust-conventions")

**Example usage:**
- `/create-skill docker-compose`
- `/create-skill rust-conventions`

---

## Prompt

I'll create a new skill called `{{skill_name}}`. Here's my process:

1. **Analyze the skill name** "{{skill_name}}" to infer its purpose:
   - Break down the name into meaningful parts
   - Determine the likely intent and use case
   - The name must be lowercase alphanumeric with hyphens only

2. **Follow the collection's conventions** — load the `skill-maintenance` skill and apply its references so the new skill is spec-compliant and consistent with the rest of the collection:
   - *best-practices*: valid frontmatter (`name` lowercase a-z/0-9/hyphens, ≤64 chars; `description` ≤1024 chars stating **what** and **when to use** with trigger keywords), progressive disclosure (`SKILL.md` < 500 lines / < 5000 tokens; move detail to `references/`; one topic per reference file; refs one level deep), self-contained scripts.
   - *dry-across-skills*: before duplicating knowledge that another skill already owns (a snippet, a convention, a discipline), give it a **single canonical home** and cross-link with `../sibling/SKILL.md` instead of copy-pasting. Surface ownership conflicts to the user.
   - *sub-division*: keep `SKILL.md` a slim index (overview + When to Use + Reference Files list + optional quick-reference); put detail in `references/`. Never let `SKILL.md` re-inline content that lives in its own `references/`.

3. **Generate the skill structure**:
   - Create YAML frontmatter with `name` and `description`
   - Write a "When to Use" section
   - Write detailed instructions (or an index pointing to `references/` if the skill is large)

4. **Show you a preview** of the generated SKILL.md and ask if you want to:
   - Use it as-is
   - Modify the description
   - Refine the instructions

5. **Save the skill** to `~/Notes/Prompts/skills/{{skill_name}}/SKILL.md`

6. **Confirm** the skill is ready to use as `/{{skill_name}}`

Let me start by analyzing the skill name and generating the initial version...
