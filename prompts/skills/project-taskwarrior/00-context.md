# Project Taskwarrior — shared context

Load this with any of the action files (1–5) when working with tasks. It defines project scope and rules that apply to all task operations.

## Project name

Derive the project name from the git repository:

```bash
basename -s .git "$(git remote get-url origin 2>/dev/null)" 2>/dev/null || basename "$(git rev-parse --show-toplevel)"
```

Use it as `project:<name>` in every `task` command.

## Rules that apply to all task commands

- **Project and tag matching:** The agent only reads, modifies, or creates tasks that have **both** `project:<name>` **and** the `+agent` tag. Do not touch any task that does not have `+agent` set.
- **EVERY `task` command MUST include `project:<name>`** — no exceptions. When listing or querying, also include `+agent` so only agent-managed tasks are shown (e.g. `task project:<name> +agent list`). Never run a bare `task` without the project filter. When using a task ID, confirm the task belongs to the current project **and** has the `+agent` tag before acting on it.
- **NEVER modify, delete, complete, start, or annotate tasks from other projects or tasks without `+agent`.** Only act on tasks where `project:<name>` matches the current git repo and the task has the `+agent` tag.
- **One task in progress per project.** Do not start a second task while another is started and not completed, unless the user explicitly asks.
- **Parallel work via sub-agents** — the agent may spawn sub-agents to work on tasks in parallel only **after the user approves**.
