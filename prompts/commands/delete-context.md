# /delete-context

**Description:** Delete a context file from ~/Notes/Prompts/context/. The command will verify the file exists before deletion and ask for confirmation to prevent accidental removal.

**Parameters:**
- context_name: The name of the context file to delete (without .md extension)

**Example usage:**
- `/delete-context epimetheus` - Deletes ~/Notes/Prompts/context/epimetheus.md
- `/delete-context old-api-guidelines` - Deletes ~/Notes/Prompts/context/old-api-guidelines.md
- `/delete-context` - Lists available context files if no name provided

---

## Prompt

I'll delete the specified context file. Here's my process:

1. **Check if context_name was provided**:
   - If not provided, list all available context files in ~/Notes/Prompts/context/
   - Show the available options and ask which one to delete

2. **Verify the context file exists**:
   - Check for ~/Notes/Prompts/context/{{context_name}}.md
   - If it doesn't exist, inform you and list available context files

3. **Show a preview of what will be deleted**:
   - Display the first few lines or a summary of the file content
   - Ask for confirmation before deletion

4. **Delete the context file**:
   - Remove ~/Notes/Prompts/context/{{context_name}}.md
   - Confirm successful deletion

5. **Safety check**:
   - Never delete without explicit confirmation
   - Provide clear feedback on what was deleted

Let me proceed with the deletion after verification.
