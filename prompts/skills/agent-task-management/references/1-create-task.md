# Create task

Use with `00-context.md`. Project name and global rules apply. New tasks get `+agent` so they are agent-managed; when setting dependencies (`dep:add:<uuid>`), use UUIDs of tasks that have `+agent` (from `ask list` output).

## Rules for new tasks

- **When creating a new task, always check whether the new task depends on other (existing) tasks.** If it does, add the dependency to the new task using `dep:add:<uuid>` with the other task's UUID. 
- **Create tasks in smaller chunks that fit into the context window.** Break work into multiple tasks so that each task's scope, description, and required context (refs, files, docs) can fit in one context window when the agent works on it with a fresh context. Do not create single tasks that would require more context than available.
- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`).
- **After creating a task, add annotation** — one with the agent workflow reminder:
  **Important:** `ask annotate` requires the short 8-character UUID (first segment, no `uuid:` prefix). Using `uuid:<full-uuid>` fails for `annotate`.
  ```
  ask annotate <short-uuid> "Agent workflow: load the agent-task-management skill as instructions only, not as a shell command. Use only normal ask subcommand syntax. Also load and apply: (1) the best-practices skill for the programming language used in the project, (2) solid-principles. When all tests and sub-agent reviews pass, commit and automatically progress to the next ready task."
  ```

- **Include references to all context required** to work on the task. So that work can be done with a fresh context, every task must list or link everything needed: relevant files, docs, specs, other tasks, or project guidelines (e.g. paths, doc links, `AGENTS.md`, `README` sections). Put these in the task description or in an initial annotation so that an agent starting with no prior conversation has everything they need in the task itself.
- When tasks refer to other tasks in free text (annotations, descriptions, docs, or commit messages).

## Add a task

`ask add` already injects `project:<name> +agent`, so only add the extra feature tag(s) and description:

```bash
ask add +<tag> "Description"
```

Then add the workflow annotation and UUID annotation. The UUID returned by `ask add` is the full UUID; use only its **first 8 characters** (short UUID) for `ask annotate`:

```bash
ask annotate <short-uuid> "Agent workflow: load the agent-task-management skill as instructions only, not as a shell command. Never run ask agent-task-management ... or other natural-language ask commands. Use only normal ask subcommand syntax. Also load and apply: (1) the best-practices skill for the programming language used in the project, (2) solid-principles, and (3) beyond-solid-principles. When all tests and sub-agent reviews pass, commit and automatically progress to the next ready task."
```

## With dependency

```bash
ask add +<tag> "Description" dep:add:<uuid>
```

Multiple dependencies: `dep:add:<uuid1> +dep:add:<uuid2>`.

After adding (with or without dependency), run the same annotations using the UUID from `ask info uuid:<uuid>`.

## Conventions

- **Keep tasks small:** each task should be a chunk that fits in the context window (description + refs + work to do). Split large efforts into multiple dependent tasks.
- Pick or create a meaningful tag for the sub-project or feature.
- **Always check for dependencies:** before adding a task, determine if it depends on other tasks in the project; if so, add `dep:add:<uuid>` with the other task's UUID.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
