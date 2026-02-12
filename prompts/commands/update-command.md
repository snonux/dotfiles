# /update-command

**Description:** Guide me step-by-step to update an existing slash command in ~/Notes/Prompts/commands/. Help me modify the description, parameters, prompt text, or any other aspect of the command.

**Parameters:**
- command_name: The name of the existing command to update (e.g., "create-command" for /create-command)

**Example usage:**
- `/update-command create-command`
- `/update-command review-code`

---

## Prompt

I need to update an existing slash command. Please follow these steps:

1. **Read the existing command file** from `~/Notes/Prompts/commands/{{command_name}}.md`
   - If the file doesn't exist, inform me and list available commands in that directory

2. **Show me the current content** of the command in a clear, organized format

3. **Ask me what I want to update** using the AskUserQuestion tool:
   - Description
   - Parameters (add, remove, or modify)
   - Prompt text/content
   - All of the above

4. **Guide me through the updates** interactively:
   - For description: Ask for the new description
   - For parameters: Show current parameters and ask what to add/remove/modify
   - For prompt text: Ask for the new prompt content or specific sections to change

5. **Show me a preview** of the updated command before saving

6. **Save the updated command** back to `~/Notes/Prompts/commands/{{command_name}}.md`

7. **Confirm** the update was successful and summarize what changed

Be helpful and thorough - make sure I understand each change and why it improves the command.
