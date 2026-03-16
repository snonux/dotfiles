# Delete Custom Prompt

Interactively delete an existing custom prompt with confirmation. Claude will show the current prompt, ask for confirmation, and only delete after explicit approval. Built-in prompts cannot be deleted.

## Usage

This prompt template accepts the following arguments:

- **prompt_name** (required): Name of the existing prompt to delete

## Template

I want to delete the existing prompt '{{prompt_name}}'.

Please help me by:
1) Confirm with me that I want to delete the prompt named '{{prompt_name}}'
2) Explain that this action cannot be undone (though backups are automatically created)
3) Ask me to type 'yes' to confirm the deletion
4) Only after I explicitly confirm with 'yes', use the delete_prompt tool to delete it

IMPORTANT NOTES:
- Built-in prompts (save_prompt, update_prompt, delete_prompt) cannot be deleted
- Only custom prompts stored in user.jsonl can be deleted
- Backups are automatically created before deletion

Ask me to confirm the deletion of '{{prompt_name}}'.

## Tags

meta, prompt-management, interactive

---
*Generated from MCP prompt: delete_prompt*
