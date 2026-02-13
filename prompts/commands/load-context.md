# /load-context

**Description:** Load a specific context file from ~/Notes/Prompts/context/ to provide background information for the conversation. Context files contain pre-written information about projects, domains, or workflows.

**Parameters:**
- context_name: The name of the context file to load (without .md extension)

**Example usage:**
- `/load-context epimetheus` - Loads ~/Notes/Prompts/context/epimetheus.md
- `/load-context api-guidelines` - Loads ~/Notes/Prompts/context/api-guidelines.md
- `/load-context` - Lists available context files if no name provided

---

## Prompt

I'll load the context file you specified. Here's my process:

1. **Check if context_name was provided**:
   - If not provided, list all available context files in ~/Notes/Prompts/context/
   - Show the available options and ask which one to load

2. **Attempt to read the context file**:
   - Read ~/Notes/Prompts/context/{{context_name}}.md
   - If the file doesn't exist, inform you and list available context files

3. **Display the context content**:
   - Show the loaded context in a clear format
   - Confirm that this context is now loaded for our conversation

4. **Ready for your next request** with this context in mind

Let me load the context for you now.
