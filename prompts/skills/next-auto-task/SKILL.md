---
name: next-auto-task
description: "Pick up and work on the next agent task tagged +auto. First tries the current git project via the `agent-task-management` skill; if no +auto task is available there, runs `ask projects +auto` to find projects with pending +auto agent tasks, then switches into the matching git repo under `~/git/` (and into a subdirectory when the project name is hierarchical, e.g. `dotfiles.prompts` → `~/git/dotfiles/prompts`) and continues with `agent-task-management`. Triggers on: next auto task, next-auto-task, auto task, work next auto, pick up next auto task."
---

# Next Auto Task

Find the highest-priority agent task tagged `+auto` to work on next, switch to the right project if needed, and hand off to the `agent-task-management` skill to execute it.

**Scope:** Only tasks with the `+auto` tag. Ignore started or ready tasks that lack `+auto`.

## Workflow

1. **Try current project first.**
   - Load the `agent-task-management` skill.
   - Run `ask list start.any: +auto` in the current git repository first. If exactly one `+auto` task is started, resume it and do not select another task. If multiple `+auto` tasks are started, report their IDs and stop so the invalid state can be reconciled explicitly.
   - Only when no `+auto` task is started, run `ask ready +auto` to find the next actionable `+auto` task.
   - If there is a started or ready `+auto` task here, proceed with the standard `agent-task-management` lifecycle (create context → start when needed → annotate → complete). **Stop — do not look across other projects.**

2. **Fall back to `+auto` tasks across projects.**
   - If the current project has no available `+auto` agent task, run:

     ```sh
     ask projects +auto
     ```

     This lists projects with at least one pending, not-yet-started agent task tagged `+auto`.
   - Read each project name from the output (one per line). Names may be hierarchical
     (`repo` or `repo.subdir…`) — see `agent-task-management` / `references/00-context.md`.
   - Prefer the first project whose mapped directory exists under `~/git/` (step 3); otherwise pick the first project listed.

3. **Switch to the target project's directory.**
   - Map the Taskwarrior project name to a filesystem path:
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
   - Load `agent-task-management` (and its `references/00-context.md` + the appropriate action file) inside the new project directory.
   - Repeat `ask list start.any: +auto` in the target project. Resume it before considering a ready task when exactly one exists; report the IDs and stop when multiple `+auto` tasks are started.
   - Only when none is started, use `ask ready +auto`.
   - Use the alias ID of the chosen task with `ask info <id>`, `ask start <id>`, etc.
   - Follow the full task lifecycle defined by `agent-task-management`: start → annotate → completion criteria → sub-agent review until clean → commit → `ask done <id>`.
   - When progressing to the next task after completion, keep the `+auto` filter (`ask list start.any: +auto`, then `ask ready +auto`). Do not pick tasks without `+auto`.

## Rules

- **Only `+auto` tasks.** Every `ask list` / `ask ready` / `ask projects` call in this skill must include `+auto`. Never start or resume a task that lacks that tag.
- **Always use `~/go/bin/ask` (or just `ask`) for agent tasks.** Do not use raw underlying commands to mutate agent-managed tasks.
- **One started task per project.** Resume the `+auto` task when exactly one is started. If multiple `+auto` tasks are started, report their IDs and stop so the invalid state can be reconciled explicitly.
- **Do not switch projects silently.** When step 2 triggers a project switch, tell the user which project and task you are moving to before starting work.
- **Direct mode for one or resumed task.** Resume an existing `+auto` task directly. When no `+auto` task is started and exactly one is ready, also work directly. Use a fresh sub-agent only when multiple `+auto` tasks are ready, following `agent-task-management`.
