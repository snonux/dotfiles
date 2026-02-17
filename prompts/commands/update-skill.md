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

3. **Ask me what I want to update** using the AskUserQuestion tool:
   - Description (YAML frontmatter)
   - When to Use section
   - Instructions
   - All of the above

4. **Guide me through the updates** interactively:
   - For description: Ask for the new description
   - For When to Use: Ask what triggers should be added or changed
   - For instructions: Ask for the new content or specific sections to change

5. **Show me a preview** of the updated skill before saving

6. **Save the updated skill** back to `~/Notes/Prompts/skills/{{skill_name}}/SKILL.md`

7. **Confirm** the update was successful and summarize what changed

Be helpful and thorough - make sure I understand each change and why it improves the skill.
