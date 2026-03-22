# Agent task management — shared context

Load this with any of the action files (1–5) when working with tasks. It defines project scope and rules that apply to all task operations.

## Project name

Derive the project name from the git repository:

```bash
basename -s .git "$(git remote get-url origin 2>/dev/null)" 2>/dev/null || basename "$(git rev-parse --show-toplevel)"
```

The `ask` command automatically injects this as `project:<name> +agent` into every command — you never need to specify these manually.

## Rules that apply to all task commands

- **Always use `ask <subcommand>` for all task operations.** The `ask` CLI provides subcommands (`list`, `add`, `info`, `start`, `stop`, `done`, `annotate`, `modify`, `tag`, `priority`, `dep`, `delete`, `urgency`) that operate on agent-managed tasks. It is not a natural-language interface and does not understand skill names.
- **Project and tag matching:** The agent only reads, modifies, or creates tasks that have **both** `project:<name>` **and** the `+agent` tag. Do not touch any task that does not have `+agent` set.
- **NEVER modify, delete, complete, start, or annotate tasks from other projects or tasks without `+agent`.** Only act on tasks where `project:<name>` matches the current git repo and the task has the `+agent` tag.
- **One task in progress per project.** Do not start a second task while another is started and not completed, unless the user explicitly asks.
- **Parallel work via sub-agents** — the agent may spawn sub-agents to work on tasks in parallel only **after the user approves**.
- **IDs are ephemeral; use UUIDs for stability.** Task IDs are working-set indices and can be renumbered when the working set is rebuilt. Use numeric IDs only within a single `list` → immediate command sequence.
- **Use UUIDs for any long-lived reference.** For anything that must survive beyond a single report (handoffs between agents, saved notes, dependencies you mention in text, "next task" pointers, etc.), resolve and use the task's UUID (from the creation annotation) and prefer `uuid:<uuid>` selectors in commands.
- **Record the UUID at creation time.** After creating a task, immediately annotate it with its UUID so it can be recovered even if numeric IDs are renumbered.