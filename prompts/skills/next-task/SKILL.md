---
name: next-task
description: "Pick up and work on the next agent task. First tries the current git project via the `agent-task-management` skill; if no task is available there, runs `ask projects` to find projects with pending agent tasks, then `cd`s into the matching project under `~/git/` and continues with `agent-task-management`. Triggers on: next task, next-task, work next, pick up next task, continue with tasks."
---

# Next Task

Find the highest-priority agent task to work on next, switch to the right project if needed, and hand off to the `agent-task-management` skill to execute it.

## Workflow

1. **Try current project first.**
   - Load the `agent-task-management` skill.
   - Run `ask ready` (or `ask list`) in the current git repository.
   - If there is an available task here, pick the next one and proceed with the standard `agent-task-management` lifecycle (create context → start → annotate → complete). **Stop — do not look across other projects.**

2. **Fall back to all agent tasks across projects.**
   - If the current project has no available agent task, run:

     ```sh
     ask projects
     ```

     This lists projects with at least one pending, not-yet-started agent task.
   - Read each project name from the output (one per line).
   - Prefer the first project whose directory exists under `~/git/`; otherwise pick the first project listed.

3. **Switch to the target project's git repository.**
   - The repository lives somewhere under `~/git/`. It may be at the top level (`~/git/<project>`) or nested in a sub-directory (e.g. `~/git/work/<project>`, `~/git/forks/<project>`). Always do a depth-3 search across all of `~/git/`:

     ```sh
     find ~/git -maxdepth 3 -type d -name '<project>' -exec test -e {}/.git \; -print
     ```

     If that returns nothing, retry with `-iname '<project>'` for a case-insensitive match. As a last resort, allow simple suffix/prefix differences (e.g. project `ior` → directory `ior-go`).
   - If multiple candidates match, prefer (in order): exact name containing `.git`, shallowest path, then ask the user.
   - If nothing plausible is found, stop and ask the user which repo to use.
   - Use the `cwd` parameter of subsequent tool calls to operate inside that repository. Do **not** chain `cd` with `&&` in tool calls — pass `cwd` instead.

4. **Continue with `agent-task-management` from there.**
   - Load `agent-task-management` (and its `references/00-context.md` + the appropriate action file) inside the new project directory.
   - Use the alias ID of the chosen task with `ask info <id>`, `ask start <id>`, etc.
   - Follow the full task lifecycle defined by `agent-task-management`: start → annotate → completion criteria → sub-agent review until clean → commit → `ask done <id>`.

## Rules

- **Always use `~/go/bin/ask` (or just `ask`) for agent tasks.** Do not use raw underlying commands to mutate agent-managed tasks.
- **One started task per project.** If `ask list` in the current project already shows a started task, resume that one instead of picking a new one (unless the user says otherwise).
- **Do not switch projects silently.** When step 2 triggers a project switch, tell the user which project and task you are moving to before starting work.
- **Fresh context per task.** Per `agent-task-management`, prefer a new session/sub-agent over carrying context from a previous task.
