# /load-skill

**Description:** Explicitly load a skill from ~/Notes/Prompts/skills/ so its instructions apply to the rest of the conversation. Each skill is a directory with a SKILL.md (YAML frontmatter: name, description) and optional references/ files.

**Parameters:**
- skill_name: The name of the skill to load (directory name, e.g., "go-best-practices")

**Example usage:**
- `/load-skill go-best-practices` - Loads ~/Notes/Prompts/skills/go-best-practices/SKILL.md
- `/load-skill f3s-k3s` - Loads the k3s reference skill
- `/load-skill` - Lists available skills (name + description) if no name provided

---

## Prompt

I'll explicitly load the skill you specified. Here's my process:

1. **Check if skill_name was provided**:
   - If not provided, list all available skills in ~/Notes/Prompts/skills/
   - For each skill directory, read its SKILL.md frontmatter and show `name` — `description`
   - Show the available options and ask which one to load

2. **Attempt to read the skill**:
   - Read ~/Notes/Prompts/skills/{{skill_name}}/SKILL.md
   - If the file doesn't exist, inform you and list available skills (fuzzy-match close names if one is obvious, e.g., typo)

3. **Load the skill**:
   - Show the full SKILL.md content in a clear format
   - If the skill lists `references/` files, note them and read any that are needed to fulfill the current task (one level deep, as referenced)
   - Repeat `name` and `description` from the frontmatter to confirm what was loaded
   - Confirm that the skill's instructions are now in effect for our conversation

4. **Apply the skill** to subsequent work:
   - Follow the skill's instructions, triggers, and conventions in this conversation
   - If the skill points to sibling skills (cross-links), load them only when relevant

Let me load the skill for you now.
