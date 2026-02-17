# /delete-skill

**Description:** Delete an existing skill by removing its directory from ~/Notes/Prompts/skills/. This command will confirm before deletion and show you which skills are available to delete.

**Parameters:**
- skill_name: The name of the skill to delete (e.g., "docker-compose", "rust-conventions")

**Example usage:**
- `/delete-skill docker-compose`
- `/delete-skill rust-conventions`

---

## Prompt

I'll help you delete the `{{skill_name}}` skill. Here's what I'll do:

1. **Verify the skill exists**:
   - Check if `~/Notes/Prompts/skills/{{skill_name}}/SKILL.md` exists
   - Show you the skill's current description and instructions

2. **Confirm deletion**:
   - Display the skill content that will be deleted
   - Ask for your confirmation before proceeding

3. **Delete the skill**:
   - Remove the entire `~/Notes/Prompts/skills/{{skill_name}}/` directory
   - Confirm successful deletion

4. **Clean up** (if applicable):
   - Note: The skill will no longer be available after deletion
   - You can always recreate it later using `/create-skill` if needed

Let me check if the skill exists and show you what will be deleted...
