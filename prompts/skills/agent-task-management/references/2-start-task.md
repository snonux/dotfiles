# Start task

Use with `00-context.md`. Project name and global rules apply (including one task in progress per project unless the user says otherwise). 

## Start each new task with a fresh context

Work on each new task **must begin with a fresh context** — a new sub-agent with no prior conversation history. That way the task is executed with clear focus and no carry-over from other work.

**If you are orchestrating via `/work-on-tasks`:** spawn a sub-agent for the implementation or even multiple sub-agents if they can work in parallel. Pass the full task description, all annotations, and the project root path to the sub-agent. Do not implement tasks in the orchestrator's own context.

**If you are starting a single task manually:** begin in a new session or compact first so the context is clean before you start working.

The task itself should already contain references to all required context (added when the task was created); read the task description and all annotations to get files, docs, and specs before starting.

## Stay within task scope

A task gives you a **scope boundary**. Only touch the code the task asked you to
change. Do **not** edit out-of-scope code:

- **Vendored / third-party dependencies** — `vendor/`, `node_modules/`, anything
  pulled from upstream and committed under the project. These are not yours to patch.
- **Generated files** — generated bindings, protobuf/`*.pb.go`, mocks, build
  artifacts. Fix the generator or its input, never the generated output by hand.
- **Upstream code the task did not name** — modules, libraries, or subsystems
  outside what the task description and annotations call for.

**If completing the task appears to require changing a vendored or upstream
dependency, STOP — treat it as a blocker, do not patch the dependency.** Patching
a vendored dep (e.g. editing `libbpfgo` under `vendor/`) gets reverted and wastes
the work. Instead:

1. Record the blocker with an annotation explaining what the task needs and which
   out-of-scope dependency stands in the way (see `4-annotate-update-task.md`):

   ```bash
   ask annotate <id> "Blocked: completing this needs a change to vendored <dep>; that is out of scope. Flagging instead of patching."
   ```

2. **Report it back** (to the orchestrator or user) as a blocker so the dependency
   change can be scoped as its own task or decided upstream.

This is about *not making* the out-of-scope edit in the first place. It is
distinct from — but complements — leaving unrelated dirty files uncommitted at
completion (see "Commit only in-scope files" in `3-complete-task.md`) and
reverting a stalled worker's broken edits (see `6-recover-stalled-task.md`).

## Finding a task

```bash
ask ready | head
```

## Mark task as started

When you begin working on a task, **always mark it as started** so current work is visible:

```bash
ask start <id>
```

Do this as soon as you start work on the task.

## Picking up an already-started task

If the task is already `start`ed but not `done`, a prior worker may have stalled
or been interrupted mid-edit, leaving broken, uncommitted, partial changes.
Before resuming, check for and clean up that situation: see
`6-recover-stalled-task.md`.

## Conventions

- Start each new task with a fresh context; rely on the task's description and annotations for all required context.
- **Stay within task scope.** Never edit vendored/third-party deps (`vendor/`, `node_modules/`), generated files, or upstream code the task did not name. If the task seems to require a vendored/upstream change, flag it as a blocker (annotate + report) instead of patching the dep — see "Stay within task scope".
- When picking up an already-started task, check for a stalled-worker situation (dirty worktree, broken build) before assuming a clean state — see `6-recover-stalled-task.md`.
- Run `ask start <id>` when you start working on the task, not only when listing or completing.
- Do not start a second task for the same project while one is already started and not done, unless the user explicitly asks.
- When a task is selected via the review/overview step, use the alias ID from the list or task details for subsequent `start` operations.
