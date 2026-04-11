# Agent task management — shared context

Load this with any of the action files (1–5) when working with tasks. It defines project scope and rules that apply to all task operations.

## Project name

## Rules that apply to all task commands

- **Always use `~/go/bin/ask <subcommand>` for all task operations.** The task CLI is installed at `~/go/bin/ask` and provides subcommands (`list`, `ready`, `add`, `info`, `start`, `stop`, `done`, `annotate`, `modify`, `tag`, `priority`, `dep`, `delete`, `urgency`) that operate on agent-managed tasks. It is not a natural-language interface and does not understand skill names.
- **Shell note:** Prefer `~/go/bin/ask` (full path) so the correct binary is used regardless of `PATH`. The binary name is `ask` (not a zsh reserved word).
- **One task in progress per project.** Do not start a second task while another is started and not completed, unless the user explicitly asks.
- **Parallel work via sub-agents** — the agent may spawn sub-agents to work on tasks in parallel if those tasks would not conflict each other.
