# /create-context

**Description:** Create a new context file in ~/Notes/Prompts/context/ that can be loaded later with /load-context. The command will guide you through creating the content and save it with the specified name.

**Parameters:**
- context_name: The name of the context file to create (without .md extension)

**Example usage:**
- `/create-context epimetheus` - Creates ~/Notes/Prompts/context/epimetheus.md
- `/create-context api-guidelines` - Creates ~/Notes/Prompts/context/api-guidelines.md

---

## Prompt

I'll create a new context file for you. Here's my process:

1. **Check if the context already exists**:
   - Look for ~/Notes/Prompts/context/{{context_name}}.md
   - If it exists, inform you and ask if you want to overwrite or choose a different name

2. **Ask you for the context content**:
   - What information should this context contain?
   - What background knowledge is relevant?
   - Any specific structure or sections needed?

3. **Create and save the context file**:
   - Write the content to ~/Notes/Prompts/context/{{context_name}}.md
   - Format it clearly with appropriate markdown structure

4. **Confirm creation**:
   - Show the file path
   - Confirm it can now be loaded with `/load-context {{context_name}}`

Let me create this context file for you now.
