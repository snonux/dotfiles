---
name: run-command
description: Runs a slash-style prompt from the user's commands library by command name only; resolves the markdown file automatically and maps user-supplied arguments onto {{placeholders}} in the command. Use when the user mentions run-command, passes parameters after the command name, or should not use a full path to a command .md file.
---

# run-command

## When to Use

- The user asks to run a slash command via `run-command` or to load a prompt by **name** (not by filesystem path).
- You need to locate the definition for commands like `create-skill`, `update-context`, etc., without hard-coding repo-specific absolute paths.
- The user insists on **command name only**; path resolution is your job.

## Arguments and parameters

- **Invocation shape:** `run-command <command-name> [arguments...]` — the first token after `run-command` is always the command basename; everything after it is input for the loaded prompt (not part of the filename).
- **Read the command header** in `<command-name>.md` for a **Parameters:** list (e.g. `skill_name`, `command_name`). Those names match `{{parameter}}` placeholders in the **Prompt** section.
- **Map user input to placeholders:**
  - If the user gives **positional** args (e.g. `run-command create-skill docker-compose`), assign them to parameters in the order listed under **Parameters:** (first arg → first parameter, and so on).
  - If the user uses **natural language** (e.g. “run create-skill for docker-compose”), infer the same mapping from names and context; ask one short clarifying question only if required parameters are missing or ambiguous.
  - If a command defines **one** parameter and the user passes **one** trailing string, treat that string as that parameter’s value.
- **Substitute** every `{{parameter}}` in the prompt with the resolved value before executing the steps. Do not leave unreplaced placeholders.

## Instructions

1. **Resolve the command file** from the **command name** (basename, no `.md`):
   - Primary: `~/Notes/Prompts/commands/<command-name>.md`
   - If that path is missing, try the same basename under any project-local commands folder the user has configured; do not guess random directories.

2. **Do not** require or construct a full path like `/home/.../dotfiles/prompts/commands/...` unless the user explicitly points you at one. The contract is: **name → single predictable file** under the commands root.

3. **Read** the resolved `.md` file. Parse the **Parameters:** block and the **Prompt** section (after the `---` separator following metadata). Resolve placeholder values using **Arguments and parameters** above.

4. **Execute** by following that prompt after substitution; run requested tools and produce the outcome the command describes.

5. If `<command-name>.md` does not exist, list available `*.md` files in `~/Notes/Prompts/commands/` (or report that the directory is missing) and stop.

## Examples

- `run-command create-skill docker-compose` → `command-name` = `create-skill`; first parameter `skill_name` = `docker-compose`; substitute `{{skill_name}}` in the prompt, then execute.
- `run-command create-skill` with no trailing arg → load the file; if the prompt needs `skill_name`, ask the user for it (or use prior message context if clearly stated).
- `run-command review-changes` → no parameters in the header (typical) → run the prompt as written.
