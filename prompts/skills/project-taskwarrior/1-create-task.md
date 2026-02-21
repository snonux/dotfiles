# Create task

Use with `00-context.md`. Project name and global rules apply.

## Rules for new tasks

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

- Pick or create a meaningful tag for the sub-project or feature.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
