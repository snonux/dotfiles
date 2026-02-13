# /update-context

**Description:** Update an existing context file in ~/Notes/Prompts/context/ by adding, modifying, or removing content. The command helps you make targeted changes to context files without recreating them from scratch.

**Parameters:**
- context_name: The name of the context file to update (without .md extension)

**Example usage:**
- `/update-context epimetheus` - Updates ~/Notes/Prompts/context/epimetheus.md
- `/update-context api-guidelines` - Updates ~/Notes/Prompts/context/api-guidelines.md
- `/update-context` - Lists available context files if no name provided

---

## Prompt

I'll update the specified context file for you. Here's my process:

1. **Check if context_name was provided**:
   - If not provided, list all available context files in ~/Notes/Prompts/context/
   - Show the available options and ask which one to update

2. **Verify the context file exists**:
   - Check for ~/Notes/Prompts/context/{{context_name}}.md
   - If it doesn't exist, inform you and suggest using `/create-context` instead
   - List available context files for reference

3. **Read and display current content**:
   - Load the existing content from ~/Notes/Prompts/context/{{context_name}}.md
   - Show you the current content or a summary
   - Understand what needs to be updated

4. **Ask about the update type**:
   - What changes do you want to make?
   - Options:
     - Add new section(s)
     - Modify existing section(s)
     - Remove outdated section(s)
     - Rewrite specific parts
     - Complete overhaul

5. **Make the updates**:
   - Apply the requested changes to the context file
   - Preserve existing structure and formatting where appropriate
   - Ensure markdown formatting is maintained

6. **Save and confirm**:
   - Write the updated content back to ~/Notes/Prompts/context/{{context_name}}.md
   - Show a summary of what was changed
   - Confirm the context file is updated and ready to use

Let me update this context file for you now.
