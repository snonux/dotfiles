---
name: next-auto-task
description: "Pick up and work on the next agent task tagged +auto that is due within 7 days (or has no due date). First tries the current git project via the `agent-task-management` skill; if no eligible +auto task is available there, runs `ask projects +auto due-window:7.days` and probes each project for due-window-eligible ready tasks, then switches into the matching git repo under `~/git/` (and into a subdirectory when the project name is hierarchical, e.g. `dotfiles.prompts` → `~/git/dotfiles/prompts`) and continues with `agent-task-management`. After each completed task, commit (if needed), push the git repo, and when applicable bump/publish the app version via `increment-version-and-push`. Triggers on: next auto task, next-auto-task, auto task, work next auto, pick up next auto task."
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
   - Run `ask list start.any: +auto` in the current git repository first. If exactly one `+auto` task is started, resume it and do not select another task. If multiple `+auto` tasks are started, report their IDs and stop so the invalid state can be reconciled explicitly.
   - Only when no `+auto` task is started, find the next due-window-eligible ready `+auto` task with `ask ready +auto due-window:7.days` (sorted by priority, then urgency).
   - If there is a started or eligible ready `+auto` task here, proceed with the standard `agent-task-management` lifecycle (create context → start when needed → annotate → complete), then **Post-completion: commit, push, version**. **Stop — do not look across other projects** until that post-completion finishes (then you may progress to the next `+auto` task in this project).

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
   - Repeat `ask list start.any: +auto` in the target project. Resume it before considering a ready task when exactly one exists; report the IDs and stop when multiple `+auto` tasks are started.
   - Only when none is started, select from due-window-eligible ready `+auto` tasks (`ask ready +auto due-window:7.days`).
   - Use the alias ID of the chosen task with `ask info <id>`, `ask start <id>`, etc.
   - Follow the full task lifecycle defined by `agent-task-management`: start → annotate → completion criteria → sub-agent review until clean → commit → `ask done <id>`.
   - After every completed task, run **Post-completion: commit, push, version** (below) in that project before selecting the next task.
   - When progressing to the next task after completion, keep the `+auto` filter and the due-window filter (`ask list start.any: +auto`, then `ask ready +auto due-window:7.days`). Do not pick tasks without `+auto`, and do not pick far-future-due `+auto` tasks.

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

- **Only `+auto` tasks.** Every `ask list` / `ask ready` / `ask projects` call in this skill must include `+auto`. Never start or resume a task that lacks that tag.
- **Due-window on ready picks.** Never start a ready `+auto` task due more than 7 days from now; always select with `due-window:7.days`. Undated tasks remain eligible. Started `+auto` tasks always resume.
- **Always use `~/go/bin/ask` (or just `ask`) for agent tasks.** Use only `ask` subcommands and filters to read or change agent-managed tasks.
- **One started task per project.** Resume the `+auto` task when exactly one is started. If multiple `+auto` tasks are started, report their IDs and stop so the invalid state can be reconciled explicitly.
- **Do not switch projects silently.** When step 2 triggers a project switch, tell the user which project and task you are moving to before starting work.
- **Direct mode for one or resumed task.** Resume an existing `+auto` task directly. When no `+auto` task is started and exactly one due-window-eligible task is ready, also work directly. Use a fresh sub-agent only when multiple eligible `+auto` tasks are ready, following `agent-task-management`.
- **Commit + push after each completed task.** Task commits must be pushed before moving on (subject to Darwin/dotfiles pull-only, in-scope-only push, and project rules). Post-completion runs before picking the next task.
- **Version bump when applicable (batched).** For shippable apps with product-code changes, run `increment-version-and-push` once per project per run when leaving that project or when no more due-window `+auto` remain there — not after every intermediate task. Skip skills/docs/chore-only work and unclear cases.
