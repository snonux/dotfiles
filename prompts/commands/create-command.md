# /create-command

**Description:** Create a new slash command by inferring its purpose and prompt from the command name. The command will analyze the name, generate an appropriate description and prompt, then save it to ~/Notes/Prompts/commands/.

**Parameters:**
- command_name: The name of the new command to create (e.g., "review-code", "explain-error", "optimize-function")

**Example usage:**
- `/create-command review-code`
- `/create-command explain-error`

---

## Prompt

I'll create a new slash command called `/{{command_name}}`. Here's my process:

1. **Analyze the command name** "{{command_name}}" to infer its purpose:
   - Break down the name into meaningful parts
   - Determine the likely intent and use case
   - Identify what parameters it might need

2. **Generate the command structure**:
   - Create an appropriate description based on the inferred purpose
   - Define relevant parameters if applicable
   - Write a detailed prompt that accomplishes the command's goal

3. **Show you a preview** of the generated command and ask if you want to:
   - Use it as-is
   - Modify the description
   - Adjust the parameters
   - Refine the prompt text

4. **Save the command** to `~/Notes/Prompts/commands/{{command_name}}.md`

5. **Confirm** the command is ready to use as `/{{command_name}}`

Let me start by analyzing the command name and generating the initial version...
