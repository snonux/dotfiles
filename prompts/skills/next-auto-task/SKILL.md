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
   - Load the `agent-task-management` skill.
   - Run `ask list start.any: +auto` in the current git repository first. Resume every started `+auto` task before selecting another one (see **Started tasks** below).
   - Only when no `+auto` task is started, find the next due-window-eligible ready `+auto` task with `ask ready +auto due-window:7.days` (sorted by priority, then urgency).
   - If there is a started or eligible ready `+auto` task here, proceed with the standard `agent-task-management` lifecycle (create context → start when needed → annotate → complete), then **Post-completion: commit, push, version**. Do not look across other projects while this project still has a started or eligible `+auto` task (see **When to stop**).

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
   - Load `agent-task-management`, its `references/00-cli.md`,
     `references/00-project-scope.md`, and the appropriate action file inside
     the new project directory.
   - Repeat `ask list start.any: +auto` in the target project and resume every started `+auto` task before considering a ready one (see **Started tasks**).
   - Only when none is started, select from due-window-eligible ready `+auto` tasks (`ask ready +auto due-window:7.days`).
   - Use the alias ID of the chosen task with `ask info <id>`, `ask start <id>`, etc.
   - Follow the full task lifecycle defined by `agent-task-management`: start → annotate → prove the change (red first) → completion criteria → sub-agent review within the review budget → commit → `ask done <id>`.
   - After every completed task, run **Post-completion: commit, push, version** (below) in that project before selecting the next task.
   - When progressing to the next task after completion, keep the `+auto` filter and the due-window filter (`ask list start.any: +auto`, then `ask ready +auto due-window:7.days`). Do not pick tasks without `+auto`, and do not pick far-future-due `+auto` tasks.

## Started tasks

A started `+auto` task always resumes, whatever its due date, and before any
ready task is selected. Several started `+auto` tasks are a normal state (an
interrupted parallel run leaves them behind), not an error. Count them with
the ready tasks you would pick and apply the threshold in
`agent-task-management` [2-start-task.md](../agent-task-management/references/2-start-task.md):
exactly one task → work directly; two or more → one worker per task, subject
to the parallelism rules and memory guard in
[7-orchestrating-task-batches.md](../agent-task-management/references/7-orchestrating-task-batches.md).
Workers may be cloud agents when available and suitable ("Cloud workers"
there); that is optional. Recover each started task with
[6-recover-stalled-task.md](../agent-task-management/references/6-recover-stalled-task.md)
before editing it.

## When to stop

Keep working through eligible `+auto` tasks:

1. After each completed task and its post-completion, pick the next started or
   due-window-eligible `+auto` task in the **same project**.
2. When the project has none left, run the batched version step (below) for it,
   then fall back to other projects (workflow step 2), telling the user which
   project and task you are moving to.
3. Stop when no started or due-window-eligible `+auto` task remains in any
   project, when a task hits a hard blocker you cannot resolve within scope
   (annotate it and report it), or at any limit the user stated (for example
   "just one task").

Then report the completed tasks, any blocked or skipped ones with reasons, and
any commits left unpushed or versions not bumped, with why.

## Post-completion: commit, push, version

This skill **overrides** `agent-task-management`'s "immediately pick the next task" step: after `ask done <id>`, finish the git/publish side-effects below in the project directory you used, **then** select the next `+auto` task.

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

3. **Increment and publish the app version when applicable (batched).**
   - Load `increment-version-and-push` (and `references/fdroid-release.md` when relevant).
   - **Do not bump after every task.** After each completed product-code task, remember that the project may need a release. Run the bump **once** when leaving the project or when that project has no further due-window-eligible `+auto` tasks — covering product commits since the previous version tag (they may already be pushed; the batch is about **untagged** work, not unpushed).
   - **Applicable when all of these hold:**
     - The repo is a **shippable app** with a documented release path: Flutter/`pubspec.yaml` + Android (especially snonux F-Droid apps), or AGENTS.md/README clearly describes releasing this app — not a library/CLI that merely has a version file, **and**
     - Since the last version tag there are product/runtime or user-facing commits from this `/next-auto-task` run (not only `prompts/skills/`, docs-only, or chore/CI-only), **and**
     - HEAD is on the default branch (`main`/`master`), in sync with upstream except for the commits you are releasing, and free of unrelated dirty paths, **and**
     - You have not already created a version tag for this batch in the current run.
   - When applicable: follow `increment-version-and-push` (patch by default; use that skill's minor-bump guidance for significant features), including F-Droid changelogs, tag, push commit+tag, and F-Droid publish hooks.
   - When **not** applicable: skip versioning; still push task commits from step 2 when allowed.
   - If applicability is unclear, skip the bump, say why, and push commits only.

4. **Skills repo sync.** If the completed work edited `~/git/dotfiles/prompts/skills/`, use `commit-skills` for commit+push of that tree (non-Darwin only).
## Rules

- **Only `+auto` tasks.** Every `ask list` / `ask ready` / `ask projects` call
  includes `+auto`; never start or resume a task without it.
- **Due window on every ready pick** (`due-window:7.days`); started tasks
  always resume.
- **Only `ask` subcommands** (`~/go/bin/ask` or `ask`) read or change agent tasks.
- **No silent project switches**, and post-completion (commit, push, batched
  version) runs before the next task is picked.
