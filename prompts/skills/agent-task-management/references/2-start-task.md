# Start task

Use with `00-cli.md` and `00-project-scope.md`. Several tasks may be started at
once (one per parallel worker); the parallelism policy and memory guard live in
[7-orchestrating-task-batches.md](7-orchestrating-task-batches.md).

Most of the time the role card is enough: [card-worker.md](card-worker.md), or
[card-orchestrator.md](card-orchestrator.md) when you run several tasks. This
file is the detail behind them.

## Start each new task with a fresh context

Work on each new task **must begin with a fresh context** — a new sub-agent with no prior conversation history. That way the task is executed with clear focus and no carry-over from other work.

**If you are orchestrating via the manual [work-on-tasks skill](../../work-on-tasks/SKILL.md):** run `ask list start.any:` before checking `ask ready`.

- **Resume all already-started tasks first**, before selecting anything from `ask ready`. Follow the stalled-task recovery guidance below before editing each one.
  - **Exactly one task to work on in total** (one started, none ready, or none started and one ready) → handle it directly in the orchestrator's own context. Do **not** spawn a sub-agent; the fresh-context overhead is not worth it for a single task.
  - **2 or more tasks to work on** (started and/or ready) → spawn one sub-agent per task, in parallel, subject to the memory guard and the conflict rules in [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md). Instruct each to run `ask info <id>` first so it loads the full description and annotations, and tell it not to spawn nested sub-agents. (A cloud worker cannot reach `ask`; see [7b-cloud-workers-and-worktrees.md](7b-cloud-workers-and-worktrees.md) for how its prompt differs.) Do not implement these tasks in the orchestrator's own context. The orchestrator owns all review launches.
  - An explicit user limit (for example "sequentially" or "at most 2 agents") overrides the parallel default; then work through the tasks within that limit.

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
dependency, park the task — do not patch the dependency.** Patching
a vendored dep (e.g. editing `libbpfgo` under `vendor/`) gets reverted and wastes
the work. Instead:

1. Park it with the question, which records the blocker and hides the task
   from `ask ready` (see [8-blocked-and-handoff.md](8-blocked-and-handoff.md)):

   ```bash
   ask park <id> "Completing this needs a change to vendored <dep>. May I change it, or should that become its own task?"
   ```

2. **Report it back.** A launched worker reports to its orchestrator and
   stops; an orchestrator or a solo agent continues with the next task.

This is about *not making* the out-of-scope edit in the first place. It is
distinct from — but complements — leaving unrelated dirty files uncommitted at
completion (see `3c-commit-in-scope.md`) and
reverting a stalled worker's broken edits (see `6-recover-stalled-task.md`).

## Prove the change (red first)

This section is the canonical home for how a change is proven. Other skills
(for example the audit's task annotations) link here instead of restating it.

- **Bug fixes and behaviour changes: write the test first.** Write a test that
  enters through the affected public behaviour and checks what its user would
  see. Run it before changing the code and see it **fail for the reason you
  expect**. A test that passes before the fix, or fails for another reason,
  does not prove anything yet. Then make the smallest change that makes it
  pass. Record the failing run in an annotation (test name and the relevant
  output line) so the reviewer can see it:

  ```bash
  ask annotate <id> "Red first: TestParseEmptyHeader failed with 'index out of range'; passes after the fix."
  ```

  Always start this annotation with `Red first:` and name the test; the
  reviewer looks for exactly that.

- **Fix the cause.** Reproduce the problem first. A guard that only hides the
  symptom (an extra nil check, a retry, a catch-all) is not a fix.
- **Refactoring: pin behaviour first.** Before changing structure, make sure
  tests at the public boundary pin down what the code does now. Add
  characterization tests if they are missing. Change the structure, then show
  that the same tests still pass without being edited.
- **Subtract before you add.** Prefer removing code or indirection to adding a
  new abstraction. Ship the smallest change that meets the task.
- **When an honest automated test is impractical** (hardware, UI, external
  service), do not write a test that merely mirrors the implementation. Name
  the manual or integration check, run it, and record the result instead.
- **Two failed fixes on one assumption: stop and question it.** If two fixes
  that rest on the same assumption fail the same check, stop that retry path.
  Write the shared assumption down in one sentence, inspect the actual state
  and boundary behaviour, and only then try another fix or a full rerun. Note
  whether the failure is a product defect or a test-driver, fixture, or
  resource problem.

- **Annotate milestones, not steps.** One annotation when something a later
  reader needs has changed: a decision, a finished part, a blocker. Session
  history showed four to six annotations per task and task histories of up to
  60,000 characters that every later reader paid for. Read a task in full
  once (`ask info <id>`); after that use `ask info <id> last:3`.
- **Use the project's words.** If the project has a `GLOSSARY.md`, name things
  with its terms. When the task introduces a new domain term, add it there
  with a one-line definition. Do not create a glossary for a project that has
  none unless the task asks for it.
- **Accepting a complex function.** If the change-risk check in
  [3b-review-checklist.md](3b-review-checklist.md) flags a function that is not
  worth splitting or testing further, record why:
  `ask annotate <id> "CRAP accepted: <function>: <reason>"`.

Pure documentation, configuration, or chore tasks with no behaviour to test
skip the red-first step. Say so in the completion annotation.

## Finding a task

```bash
ask list start.any:
```

Resume all started tasks first. Then, for the free worker slots (if any), run:

```bash
ask ready | head
```

and skip ready tasks that conflict with a started or running one.

## Mark task as started

When you begin working on a task, **always mark it as started** so current work is visible:

```bash
ask start <id>
```

Do this as soon as you start work on the task. A worker launched by an
orchestrator skips it: the orchestrator ran `ask start` before launching, and
it also runs `ask done`.

## Picking up an already-started task

If the task is already `start`ed but not `done`, a prior worker may have stalled
or been interrupted mid-edit, leaving broken, uncommitted, partial changes.
Before resuming, check for and clean up that situation: see
`6-recover-stalled-task.md`.

## Conventions

- Start each new task with a fresh context; rely on the task's description and annotations for all required context.
- **Stay within task scope.** Never edit vendored/third-party deps (`vendor/`, `node_modules/`), generated files, or upstream code the task did not name. If the task seems to require a vendored/upstream change, park it (`ask park`) instead of patching the dep — see "Stay within task scope".
- **Prove the change.** Bug fixes and behaviour changes start with a test seen failing for the expected reason, recorded in an annotation; refactors pin behaviour first — see "Prove the change (red first)".
- When picking up an already-started task, check for a stalled-worker situation (dirty worktree, broken build) before assuming a clean state — see `6-recover-stalled-task.md`.
- Run `ask start <id>` when you start working on the task (orchestrator or solo agent; a launched worker does not).
- Do not start a new task while an already-started task in scope is still unresumed; resume the started ones first. Starting several tasks in parallel is fine when they do not conflict and the memory guard allows it.
- When a task is selected via the review/overview step, use the alias ID from the list or task details for subsequent `start` operations.
