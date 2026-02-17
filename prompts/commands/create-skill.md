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

2. **Generate the skill structure**:
   - Create YAML frontmatter with `name` and `description`
   - Write a "When to Use" section
   - Write detailed instructions for the skill

3. **Show you a preview** of the generated SKILL.md and ask if you want to:
   - Use it as-is
   - Modify the description
   - Refine the instructions

4. **Save the skill** to `~/Notes/Prompts/skills/{{skill_name}}/SKILL.md`

5. **Confirm** the skill is ready to use as `/{{skill_name}}`

Let me start by analyzing the skill name and generating the initial version...
