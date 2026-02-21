# Create task

Use with `00-context.md`. Project name and global rules apply.

## Rules for new tasks

- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`).
- **When an agent creates a task, always add the tag `+agent`** so agent-created tasks can be identified.

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
