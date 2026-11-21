---
name: next-auto-task
description: "Pick up and work on the next agent task tagged +auto that is due within 7 days (or has no due date), in the current git project or else in another project's repo under ~/git, then commit, push and bump the version when applicable. Triggers on: next auto task, next-auto-task, auto task, work next auto, pick up next auto task."
disable-model-invocation: true
---

# Next Auto Task

Find the highest-priority agent task tagged `+auto` to work on next, switch to the right project if needed, and hand off to the `agent-task-management` skill to execute it.

**Scope:** Only tasks with the `+auto` tag. Ignore started or ready tasks that lack `+auto`.

## Due-window filter (mandatory)

When selecting a **ready** (not yet started) `+auto` task, only consider tasks that are **due-window eligible**: no due date, or due within the next 7 days (overdue included). `ask` has a filter for exactly this:

```sh
ask ready +auto due-window:7.days
```

- `due-window:7.days` matches tasks without a due date **or** due by now + 7 days (inclusive, overdue included). `due-within:7.days` is the same without the undated tasks.
- Tasks due further out are **not eligible** — skip them even if they appear in unfiltered `ask ready +auto`.
- **Scheduled tasks:** `ask ready` already hides tasks scheduled for the future. Do not special-case them beyond that; do not invent a separate path to start not-yet-scheduled tasks early.
- **Started tasks:** always resume a started `+auto` task regardless of due dates.

Every ready pick in this skill must use `due-window:7.days`. Plain `ask ready +auto` without it is only a discovery aid — never start a task that fails the window check.

## Workflow

1. **Try current project first.**
   - Read `agent-task-management`'s [card-orchestrator.md](../agent-task-management/references/card-orchestrator.md) and [card-worker.md](../agent-task-management/references/card-worker.md); they are the task lifecycle.
   - Run `ask list start.any: +auto` in the current git repository first. Resume every started `+auto` task before selecting another one (see **Started tasks** below).
   - Only when no `+auto` task is started, find the next due-window-eligible ready `+auto` task with `ask ready +auto due-window:7.days` (sorted by priority, then urgency).
   - If there is a started or eligible ready `+auto` task here, work on it as the cards describe, then **Post-completion: commit, push, version**. Do not look across other projects while this project still has a started or eligible `+auto` task (see **When to stop**).

2. **Fall back to `+auto` tasks across projects.**
   - If the current project has no available due-window-eligible `+auto` agent task, run:

     ```sh
     ask projects +auto due-window:7.days
     ```

     This lists projects with at least one pending, not-yet-started, due-window-eligible agent task tagged `+auto`. It does not check whether those tasks are blocked by dependencies, so treat the list as candidates only.
   - Read each project name from the output (one per line). Names may be hierarchical
     (`repo` or `repo.subdir…`) — see `agent-task-management` /
     `references/00-project-scope.md`.
   - For each candidate project, probe eligibility **before** switching:

     ```sh
     ask proj:<name> ready +auto due-window:7.days
     ```

   - Prefer the first project that has at least one due-window-eligible ready `+auto` task and whose mapped directory exists under `~/git/` (step 3). Skip projects whose only `+auto` tasks are due more than 7 days out. If none qualify, stop and tell the user there is no due-window-eligible `+auto` task.

3. **Switch to the target project's directory.**
   - Map the `ask` project name to a filesystem path:
     - Split on `.`: first segment is the git repo name; remaining segments are a subdirectory path.
     - Examples: `hexai` → `~/git/hexai`; `dotfiles.prompts` → `~/git/dotfiles/prompts`; `dotfiles.prompts.skills` → `~/git/dotfiles/prompts/skills`.
     - Use the deepest existing directory on that path (fall back toward the repo root if a segment is missing on disk).
   - Check that the resolved path is inside a git repo:

     ```sh
     test -d <resolved>/.git || git -C <resolved> rev-parse --show-toplevel
     ```

     If the top-level `~/git/<repo>` directory does not exist, retry with a case-insensitive match or simple suffix/prefix differences (e.g. project `ior` → directory `ior-go`) before asking the user.
   - If nothing plausible is found, stop and ask the user which repo to use.
   - Use the `cwd` parameter of subsequent tool calls to operate inside that directory (prefer the subdirectory when the project is hierarchical, so new tasks stay under the same project name). Do **not** chain `cd` with `&&` in tool calls — pass `cwd` instead.

4. **Continue with `agent-task-management` from there.**
   - Work inside the new project directory. Load an `agent-task-management`
     reference only when its card says so.
   - Repeat `ask list start.any: +auto` in the target project and resume every started `+auto` task before considering a ready one (see **Started tasks**).
   - Only when none is started, select from due-window-eligible ready `+auto` tasks (`ask ready +auto due-window:7.days`).
   - Use the alias ID of the chosen task with `ask info <id>`, `ask start <id>`, etc.
   - Follow [card-worker.md](../agent-task-management/references/card-worker.md) for the work and steps 5 and 6 of the orchestrator card for review and `ask done <id> "<summary>"`.
   - After every completed task, run **Post-completion: commit, push, version** (below) in that project before selecting the next task.
   - When progressing to the next task after completion, keep the `+auto` filter and the due-window filter (`ask list start.any: +auto`, then `ask ready +auto due-window:7.days`). Do not pick tasks without `+auto`, and do not pick far-future-due `+auto` tasks.

## Started tasks

A started `+auto` task always resumes, whatever its due date, before any
ready task is selected. Several started `+auto` tasks are normal (an
interrupted run leaves them behind): resume all of them, as step 1 and 2 of
[card-orchestrator.md](../agent-task-management/references/card-orchestrator.md)
describe. Read each one's `Handoff:` annotation first (`ask info <id> last:3`).

## When to stop

Keep working through eligible `+auto` tasks:

1. After each completed task and its post-completion, take the next started
   or due-window-eligible `+auto` task in the **same project**.
2. When the project has none left, run the batched version step (below), then
   fall back to other projects (workflow step 2), telling the user which
   project and task you are moving to.
3. A task that needs a human is parked, not a reason to stop:
   `ask park <id> "<question>"`, then take the next one.
4. Stop when no started or eligible `+auto` task remains in any project
   except parked ones, or at a limit the user stated ("just one task").

Then report the completed tasks, the parked questions, and any commits left
unpushed or versions not bumped, with why.

## Post-completion: commit, push, version

This skill inserts a step before the orchestrator card's "take the next task": after `ask done <id>`, finish the git/publish side-effects below in the project directory you used, **then** select the next `+auto` task.

1. **Commit remaining in-scope work (if any).**
   - Follow `agent-task-management` commit rules: stage only in-scope paths by explicit path; never sweep unrelated dirty files.
   - If the completion commit was already made during the lifecycle, do not create an empty commit.
   - **Darwin + `~/git/dotfiles`:** do not commit (pull-only; see `commit-skills`). Report pending skill/dotfile changes instead.
   - Edits under `~/git/dotfiles/prompts/skills/` are owned by step 4 (`commit-skills`) — do not commit them in this step.

2. **Push commits created for this task.**
   - Inspect `git log @{upstream}..HEAD` (or equivalent). Push **only when every ahead commit was created for this task** in the current run. If any ahead commit is foreign (user WIP / sibling worker), skip push, report it, and leave the branch unpushed.
   - When push is appropriate:

     ```sh
     git push -u origin HEAD
     ```

   - Never `--force` unless the user explicitly asked.
   - **Darwin + `~/git/dotfiles`:** never push (pull-only).
   - If there is no remote or push fails, report it to the user (and annotate if a pending task ID still exists); do not hide a failed push.

3. **Version bump, batched.** Not after every task: once, when leaving a
   project or when it has no eligible `+auto` task left, and only for a
   shippable app with product-code commits since its last tag. When that
   moment comes, read [references/version-bump.md](references/version-bump.md).

4. **Skills repo sync.** If the completed work edited `~/git/dotfiles/prompts/skills/`, use `commit-skills` for commit+push of that tree (non-Darwin only).
## Rules

- **Only `+auto` tasks.** Every `ask list` / `ask ready` / `ask projects` call
  includes `+auto`; never start or resume a task without it.
- **Due window on every ready pick** (`due-window:7.days`); started tasks
  always resume.
- **Only `ask` subcommands** (`~/go/bin/ask` or `ask`) read or change agent tasks.
- **No silent project switches**, and post-completion (commit, push, batched
  version) runs before the next task is picked.
