# Create task

Use with `00-context.md`. Project name and global rules apply. New tasks get `+agent` so they are agent-managed. When a new task depends on existing tasks, add those dependencies inline during creation with `depends:<id>,...`.

## Rules for new tasks

- **When creating a new task, always check whether the new task depends on other (existing) tasks.** If it does, add those dependencies inline with `depends:<id>,...` while creating the task.
- **Create tasks in smaller chunks that fit into the context window.** Break work into multiple tasks so that each task's scope, description, and required context (refs, files, docs) can fit in one context window when the agent works on it with a fresh context. Do not create single tasks that would require more context than available.
- **Every task MUST have at least one tag** for sub-project/feature/area (e.g. `+integrationtests`, `+flamegraph`, `+bpf`, `+cli`, `+refactor`, `+bugfix`). **Tag names cannot contain hyphens (`-`)**; use camelCase or concatenated words instead (e.g. `+bugfix` not `+bug-fix`).
- **After creating a task, add annotation** — one with the agent workflow reminder:
  ```
  ask annotate <id> "Agent workflow: load the agent-task-management skill as instructions only, not as a shell command. Use only normal ~/go/bin/ask subcommand syntax. Also load and apply: (1) the best-practices skill for the programming language used in the project, (2) solid-principles. When all tests and sub-agent reviews pass, commit and automatically progress to the next ready task."
  ```

- **Include references to all context required** to work on the task. So that work can be done with a fresh context, every task must list or link everything needed: relevant files, docs, specs, other tasks, or project guidelines (e.g. paths, doc links, `AGENTS.md`, `README` sections). Put these in the task description or in an initial annotation so that an agent starting with no prior conversation has everything they need in the task itself.
- When tasks refer to other tasks in free text (annotations, descriptions, docs, or commit messages).

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
ask annotate "$id" "Agent workflow: load the agent-task-management skill as instructions only, not as a shell command. Never run ~/go/bin/ask agent-task-management ... or other natural-language ~/go/bin/ask commands. Use only normal ~/go/bin/ask subcommand syntax. Also load and apply: (1) the best-practices skill for the programming language used in the project, (2) solid-principles, and (3) beyond-solid-principles. When all tests and sub-agent reviews pass, commit and automatically progress to the next ready task."
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

## Audit task batches — create a closure gate, then a tagging task

**Only the top-level audit orchestrator** creates these close-out tasks —
never a sub-skill or sub-agent that is only filing findings (e.g.
**find-code-bugs** mid-sweep). Filing `+bugfix` / `+codequality` tasks alone
does **not** trigger this section.

When the tasks being created are the output of a **code audit** (tagged
`+bugfix` from a bug sweep and/or `+codequality` from a design/convention
audit, e.g. produced by `find-code-bugs`, `solid-principles`,
`beyond-solid-principles`, or `go-best-practices` — **not** when
**auditing-code-quality** is already driving; that skill owns gate+tag),
**and** you are the top-level orchestrator closing the batch, create two
extra `+audit` tasks after all the audit finding tasks exist:

### 1. Closure gate (verification)

- Tag it `+audit` (never `+audit-something` with a hyphen; `+audit` is the tag).
- Add **every** audit finding task ID as a dependency in one `ask add`:
  ```bash
  ask add +audit depends:<id1>,<id2>,...,<idN> "Finalize <project> code-quality audit: verify all audit-driven fixes landed, re-run guardrails (build/vet/test -race/gofmt -l/linters), close out verification"
  ```
- Do not set a priority modifier — the `depends:` list is what makes it a gate;
  its readiness is driven by its dependents completing.
- Annotate it with the dependent ID list and the guardrail commands to re-run
  when it becomes READY (for Go: `go build ./...`, `go vet ./...`,
  `go test -race ./...`, `gofmt -l .`, `errcheck ./...`; adapt to the language),
  plus the instruction to confirm every dependent is done via `ask list` and
  then mark the gate done. Note that a separate tagging task still owns the
  `audit/<date>` git marker afterward.

This gate is the **verification** close-out only — not the git/`audit-due`
end marker.

### 2. Tagging task (mandatory last; depends on the gate)

- After the gate exists, create one last `+audit` task that `depends:` only on
  the gate's alias ID:
  ```bash
  ask add +audit depends:<gate-id> "Tag <project> that the code-quality audit is done: follow the audit-tagging skill to move the audit/<date> marker to the post-fix HEAD and push the end marker"
  ```
- Annotate it with the exact `$START_TAG` name (including any `-N` suffix) and
  instructions to load **audit-tagging** for the end-marker + push steps —
  do not paste `git tag` / `git push` commands here. See
  **auditing-code-quality** workflow §6 for the full annotation checklist.

Skip **both** the gate and the tagging task when the audit produced no finding
tasks (e.g. no git root, or no findings filed) — in that case there is nothing
to gate. Do not create a gate with an empty `depends:` list.

**When `auditing-code-quality` is driving the run, do not create gate or
tagging tasks from this section** — that skill's workflow §5–6 are the sole
owners (avoids a second gate/tag pair, or a gate missing `+bugfix` deps).
Use this section only for non-ACQ audit entry points (e.g. a standalone
**find-code-bugs** / design-audit pass that still wants a batch close-out).

For ATM-only batches: if no `$START_TAG` is in context yet, run
**audit-tagging** **Start tag** at tagging-task create time, store the exact
name in the annotation, then End/push when READY.

## Conventions

- **Keep tasks small:** each task should be a chunk that fits in the context window (description + refs + work to do). Split large efforts into multiple dependent tasks.
- Pick or create a meaningful tag for the sub-project or feature. **Tags cannot contain hyphens (`-`)** — use camelCase or concatenated words (e.g. `+codeReview`, `+bugfix`).
- **Always check for dependencies:** before adding a task, determine if it depends on other tasks in the project; if so, add `depends:<id>,...` during `ask add`.
- Add dependencies when one task must complete before another can start.
- When creating a task, add references to all required context (files, docs, specs) so the task is self-contained for fresh-context work.
