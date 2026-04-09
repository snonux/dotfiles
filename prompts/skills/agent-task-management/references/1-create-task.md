# Create task

Use with `00-context.md`. Project name and global rules apply. New tasks get `+agent` so they are agent-managed. When a new task depends on existing tasks, add those dependencies inline during creation with `depends:<id>,...`.

## Rules for new tasks

- **When creating a new task, always check whether the new task depends on other (existing) tasks.** If it does, add those dependencies inline with `depends:<id>,...` while creating the task.
- **Create tasks in smaller chunks that fit into the context window.** Break work into multiple tasks so that each task's scope, description, and required context (refs, files, docs) can fit in one context window when the agent works on it with a fresh context. Do not create single tasks that would require more context than available.
- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`).
- **After creating a task, add annotation** — one with the agent workflow reminder:
  ```
  ~/go/bin/do annotate <id> "Agent workflow: load the agent-task-management skill as instructions only, not as a shell command. Use only normal ~/go/bin/do subcommand syntax. Also load and apply: (1) the best-practices skill for the programming language used in the project, (2) solid-principles. When all tests and sub-agent reviews pass, commit and automatically progress to the next ready task."
  ```

- **Include references to all context required** to work on the task. So that work can be done with a fresh context, every task must list or link everything needed: relevant files, docs, specs, other tasks, or project guidelines (e.g. paths, doc links, `AGENTS.md`, `README` sections). Put these in the task description or in an initial annotation so that an agent starting with no prior conversation has everything they need in the task itself.
- When tasks refer to other tasks in free text (annotations, descriptions, docs, or commit messages).

## Add a task

`~/go/bin/do add` already injects `project:<name> +agent`, so only add the extra feature tag(s), optional priority, optional `depends:` modifier, and description.

**Each part must be a separate shell argument — never quote tag and description together:**

```bash
~/go/bin/do add +<tag> "Description"
~/go/bin/do add priority:H +<tag> "Description"
~/go/bin/do add priority:M +<tag> "Description"
~/go/bin/do add +<tag> depends:<id1>,<id2> "Description"
```

Do NOT do this (causes tag/priority to appear in the description instead of being applied):
```bash
~/go/bin/do add "+<tag> Description"           # wrong: tag and desc in one quoted string
~/go/bin/do add "+<tag> -p M Description"      # wrong: everything in one quoted arg
```

`~/go/bin/do add` prints `created task <alias-id>`. Reuse that alias ID directly for follow-up commands:

```bash
id=$(~/go/bin/do add +<tag> "Description" | sed -n 's/^created task //p')
~/go/bin/do annotate "$id" "Agent workflow: load the agent-task-management skill as instructions only, not as a shell command. Never run ~/go/bin/do agent-task-management ... or other natural-language ~/go/bin/do commands. Use only normal ~/go/bin/do subcommand syntax. Also load and apply: (1) the best-practices skill for the programming language used in the project, (2) solid-principles, and (3) beyond-solid-principles. When all tests and sub-agent reviews pass, commit and automatically progress to the next ready task."
```

## With dependency

Add dependencies inline during task creation:

```bash
id=$(~/go/bin/do add +<tag> depends:<dep-id> "Description" | sed -n 's/^created task //p')
```

Multiple dependencies:

```bash
id=$(~/go/bin/do add +<tag> depends:<dep-id1>,<dep-id2> "Description" | sed -n 's/^created task //p')
```

After adding (with or without dependency), run the same annotations using that alias ID directly.

## Conventions

- **Keep tasks small:** each task should be a chunk that fits in the context window (description + refs + work to do). Split large efforts into multiple dependent tasks.
- Pick or create a meaningful tag for the sub-project or feature.
- **Always check for dependencies:** before adding a task, determine if it depends on other tasks in the project; if so, add `depends:<id>,...` during `~/go/bin/do add`.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
