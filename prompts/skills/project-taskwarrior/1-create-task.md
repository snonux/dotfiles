# Create task

Use with `00-context.md`. Project name and global rules apply. New tasks get `+agent` so they are agent-managed; when setting dependencies (`depends:<id>`), use IDs of tasks that have `+agent` (from `project:<name> +agent` lists).

## Rules for new tasks

- **Create tasks in smaller chunks that fit into the context window.** Break work into multiple tasks so that each task’s scope, description, and required context (refs, files, docs) can fit in one context window when the agent works on it with a fresh context. Do not create single tasks that would require more context than available.
- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`).
- **When an agent creates a task, always add the tag `+agent`** so agent-created tasks can be identified.
- **Include references to all context required** to work on the task. So that work can be done with a fresh context, every task must list or link everything needed: relevant files, docs, specs, other tasks, or project guidelines (e.g. paths, doc links, `AGENTS.md`, `README` sections). Put these in the task description or in an initial annotation so that an agent starting with no prior conversation has everything they need in the task itself.

## Add a task

```bash
task add project:<name> +<tag> +agent "Description"
```

## With dependency

```bash
task add project:<name> +<tag> +agent "Description" depends:<id>
```

Multiple dependencies: `depends:<id1>,<id2>`.

## Conventions

- **Keep tasks small:** each task should be a chunk that fits in the context window (description + refs + work to do). Split large efforts into multiple dependent tasks.
- Pick or create a meaningful tag for the sub-project or feature.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
