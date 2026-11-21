# Create task

Use with `00-cli.md` and `00-project-scope.md`. New tasks get `+agent` so they
are agent-managed. When a new task depends on existing tasks, add those
dependencies inline during creation with `depends:<id>,...`.

## Rules for new tasks

- **When creating a new task, always check whether the new task depends on other (existing) tasks.** If it does, add those dependencies inline with `depends:<id>,...` while creating the task.
- **Create tasks in smaller chunks that fit into the context window.** Break work into multiple tasks so that each task's scope, description, and required context (refs, files, docs) can fit in one context window when the agent works on it with a fresh context. Do not create single tasks that would require more context than available.
- Give each task one observable outcome and the smallest credible verification
  for that outcome. Split a broad implementation from its final multi-platform
  acceptance when the latter needs separate fixtures or long-running devices;
  preserve dependencies and every required platform check. Avoid repeating the
  same acceptance journey in each dependent task.
- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`). **Tag names cannot contain hyphens (`-`)**; use camelCase or concatenated words instead (e.g. `+bugfix` not `+bug-fix`).
- **After creating a task, add the workflow annotation.** It points at the
  worker card and nothing else:
  ```
  ask annotate <id> "Agent workflow: follow ~/.agents/skills/agent-task-management/references/card-worker.md. ask takes fixed subcommands only, never free text."
  ```
  Do **not** tell every task to load best-practices or design skills. Session
  history showed each worker and reviewer loading three or four skills
  (about 3,000 words) before a small fix because the annotation said so. Name
  an extra skill only when this task needs it, in its own annotation:
  `"Also apply: solid-principles (this task reshapes the storage interface)."`
  Older tasks still carry the long "load these skills" annotation; the worker
  card overrides it.

- **Include references to all context required** to work on the task. So that work can be done with a fresh context, every task must list or link everything needed: relevant files, docs, specs, other tasks, or project guidelines (e.g. paths, doc links, `AGENTS.md`, `README` sections). Put these in the task description or in an initial annotation so that an agent starting with no prior conversation has everything they need in the task itself.
- When tasks refer to other tasks in free text (annotations, descriptions, docs, or commit messages), include the other task's alias ID.

## Add a task

`ask add` already injects `project:<name> +agent`, so only add the extra feature tag(s), optional priority, optional `depends:` modifier, and description.

**Each part must be a separate shell argument — never quote tag and description together:**

```bash
ask add +<tag> "Description"
ask add priority:H +<tag> "Description"
ask add priority:M +<tag> "Description"
ask add +<tag> depends:<id1>,<id2> "Description"
```

Do NOT do this (causes tag/priority to appear in the description instead of being applied):
```bash
ask add "+<tag> Description"           # wrong: tag and desc in one quoted string
ask add "+<tag> -p M Description"      # wrong: everything in one quoted arg
```

`ask add` prints `created task <alias-id>`. Reuse that alias ID directly for follow-up commands:

```bash
id=$(ask add +<tag> "Description" | sed -n 's/^created task //p')
ask annotate "$id" "Agent workflow: follow ~/.agents/skills/agent-task-management/references/card-worker.md. ask takes fixed subcommands only, never free text."
```

## With dependency

Add dependencies inline during task creation:

```bash
id=$(ask add +<tag> depends:<dep-id> "Description" | sed -n 's/^created task //p')
```

Multiple dependencies:

```bash
id=$(ask add +<tag> depends:<dep-id1>,<dep-id2> "Description" | sed -n 's/^created task //p')
```

After adding (with or without dependency), run the same annotations using that alias ID directly.

## Conventions

- **Keep tasks small:** each task should be a chunk that fits in the context window (description + refs + work to do). Split large efforts into multiple dependent tasks.
- Pick or create a meaningful tag for the sub-project or feature. **Tags cannot contain hyphens (`-`)** — use camelCase or concatenated words (e.g. `+codeReview`, `+bugfix`).
- **Always check for dependencies:** before adding a task, determine if it depends on other tasks in the project; if so, add `depends:<id>,...` during `ask add`.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
