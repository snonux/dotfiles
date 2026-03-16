# Save Current Conversation as Prompt

Interactively create a new prompt template from the current conversation. Claude will analyze the conversation, ask clarifying questions about templating, show a preview, and wait for approval before saving.

## Usage

This prompt template accepts the following arguments:

- **prompt_name** (required): Unique identifier for the new prompt (lowercase, underscores allowed)
- **prompt_title** (required): Human-readable display name for the new prompt

## Template

I want to create a new prompt template named '{{prompt_name}}' with title '{{prompt_title}}'.

Please help me by:
1) Analyzing our current conversation to understand what should be templated
2) Asking me clarifying questions about:
   - What parts should be template arguments vs fixed text
   - What description would best explain this prompt's purpose
   - What tags would help categorize it
   - Whether multi-turn messages are needed
3) Showing me a complete preview of the prompt structure in a code block
4) Only after I approve, use the create_prompt tool to save it

IMPORTANT FORMATTING RULES for clarifying questions:
- Use numbered questions: 1), 2), 3)
- ANY CHOICE MUST BE NUMBERED using combined format: 1a), 1b), 1c), 2a), 2b), etc.
- NEVER use standalone letters like "a)" - always combine with question number
- NEVER use dashes (-) or bullets (•) for options
- Every option must be numbered for easy selection by the user

Examples:
  1) Question Category
  Which do you prefer?
  1a) First option
  1b) Second option
  1c) Third option

  2) Arguments
  Should this accept parameters?
  2a) No arguments - fixed behavior
  2b) Optional file_pattern argument
  2c) Multiple optional arguments

  3) Sub-items
  Consider these aspects:
  3a) First aspect to consider
  3b) Second aspect to consider
  3c) Third aspect to consider

  4) Multiple sub-questions
  4a) Sub-question one?
      Answer options here
  4b) Sub-question two?
      Answer options here

Start by examining our conversation and asking your clarifying questions using this format.

## Tags

meta, prompt-management, interactive

---
*Generated from MCP prompt: save_prompt*
