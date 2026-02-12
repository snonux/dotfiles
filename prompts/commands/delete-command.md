# /delete-command

**Description:** Delete an existing slash command by removing its definition file from ~/Notes/Prompts/commands/. This command will confirm before deletion and show you which commands are available to delete.

**Parameters:**
- command_name: The name of the command to delete (e.g., "testing", "review-code")

**Example usage:**
- `/delete-command testing`
- `/delete-command review-code`

---

## Prompt

I'll help you delete the `/{{command_name}}` command. Here's what I'll do:

1. **Verify the command exists**:
   - Check if `~/Notes/Prompts/commands/{{command_name}}.md` exists
   - Show you the command's current description

2. **Confirm deletion**:
   - Display the command file that will be deleted
   - Ask for your confirmation before proceeding

3. **Delete the command**:
   - Remove the file from `~/Notes/Prompts/commands/`
   - Confirm successful deletion

4. **Clean up** (if applicable):
   - Note: The command will no longer be available after deletion
   - You can always recreate it later using `/create-command` if needed

Let me check if the command exists and show you what will be deleted...
