# Create task

Use with `00-context.md`. Project name and global rules apply. New tasks get `+agent` so they are agent-managed; when setting dependencies (`depends:<id>`), use IDs of tasks that have `+agent` (from `project:<name> +agent` lists).

## Rules for new tasks

- **When creating a new task, always check whether the new task depends on other (existing) tasks.** If it does, add the dependency to the new task (e.g. `depends:<id>` or `depends:<id1>,<id2>`). Use IDs of tasks that have `+agent` in this project.
- **Create tasks in smaller chunks that fit into the context window.** Break work into multiple tasks so that each task’s scope, description, and required context (refs, files, docs) can fit in one context window when the agent works on it with a fresh context. Do not create single tasks that would require more context than available.
- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`).
- **When an agent creates a task, always add the tag `+agent`** so agent-created tasks can be identified.
- **After creating a task, add an annotation** so any agent working on the task is reminded to use this skill and to auto-progress: `task <id> annotate "Agent: be aware of taskwarrior-task-management skill. When all tests and sub-agent reviews pass, automatically progress to the next task in the list."` This ensures agents (including those with fresh context) know to load and follow the taskwarrior-task-management skill and to continue to the next task after completion.
- **Include references to all context required** to work on the task. So that work can be done with a fresh context, every task must list or link everything needed: relevant files, docs, specs, other tasks, or project guidelines (e.g. paths, doc links, `AGENTS.md`, `README` sections). Put these in the task description or in an initial annotation so that an agent starting with no prior conversation has everything they need in the task itself.
- **Record the task’s UUID for future reference.** After creating a task, resolve its UUID (for example, `task <id> _uuid`) and include it in an annotation such as `UUID: <uuid>` so the exact task can be recovered even if IDs are renumbered.
- When tasks refer to other tasks in free text (annotations, descriptions, docs, or commit messages), **use the other task’s UUID**, not just its numeric ID.

## Add a task

```bash
task add project:<name> +<tag> +agent "Description"
```

Then add the agent-awareness annotation (use the ID from the add output):

```bash
task <id> annotate "Agent: be aware of taskwarrior-task-management skill. When all tests and sub-agent reviews pass, automatically progress to the next task in the list."
```

Also add an annotation that records the task’s UUID, for example:

```bash
task <id> annotate "UUID: $(task <id> _uuid)"
```

## With dependency

```bash
task add project:<name> +<tag> +agent "Description" depends:<id>
```

Multiple dependencies: `depends:<id1>,<id2>`.

After adding (with or without dependency), run the same annotation: `task <id> annotate "Agent: be aware of taskwarrior-task-management skill. When all tests and sub-agent reviews pass, automatically progress to the next task in the list."`

## Conventions

- **Keep tasks small:** each task should be a chunk that fits in the context window (description + refs + work to do). Split large efforts into multiple dependent tasks.
- Pick or create a meaningful tag for the sub-project or feature.
- **Always check for dependencies:** before adding a task, determine if it depends on other tasks in the project; if so, add `depends:<id>` (or multiple IDs) to the new task.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
