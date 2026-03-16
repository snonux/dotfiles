# Update Existing Prompt

Interactively modify an existing prompt. Claude will fetch the current version, ask what changes you want, show a preview with changes highlighted, and wait for approval before updating.

## Usage

This prompt template accepts the following arguments:

- **prompt_name** (required): Name of the existing prompt to update

## Template

I want to update the existing prompt '{{prompt_name}}'.

Please help me by:
1) Ask me what changes I want to make to the prompt '{{prompt_name}}' (title, description, arguments, messages, or tags)
2) If I reference content from our current conversation, help extract and template it
3) Show me a complete preview of the updated prompt with changes highlighted
4) Only after I approve, use the update_prompt tool to save the changes

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

  2) Changes to Make
  What aspects should be updated?
  2a) Description only
  2b) Arguments only
  2c) Both description and arguments
  2d) Complete rewrite

  3) Multiple aspects
  Consider:
  3a) First aspect to evaluate
  3b) Second aspect to evaluate
  3c) Third aspect to evaluate

Start by asking me what changes I want to make, using this format for any clarifying questions.

## Tags

meta, prompt-management, interactive

---
*Generated from MCP prompt: update_prompt*
