---
name: run-command
description: "Resolve an explicitly requested named workflow from the user's skills library and pass through its arguments, with support for configured legacy command files. Use when the user explicitly asks for run-command or asks to execute a named prompt without giving its path."
---

# run-command

The shared prompt commands have moved to skills. Keep `run-command <name>
[arguments...]` working by loading the requested skill directly. Only dispatch
after an explicit user request; a mention of a manual-only skill is not an
instruction to load or run it.

## Arguments and parameters

- The first token after `run-command` is the workflow basename; trailing text is
  input to the workflow, never part of its filename.
- Read the resolved skill's parameter instructions and map positional or natural
  language arguments accordingly. Apply documented defaults. Ask only when a
  required value is missing or ambiguous.
- For a legacy command file, read its **Parameters:** and **Prompt** sections and
  substitute every `{{parameter}}` with the supplied value. A single trailing
  string supplies a single parameter; honor any documented placeholder defaults.

## Instructions

1. Resolve `<name>/SKILL.md` under `~/.agents/skills/`, then
   `~/Notes/Prompts/skills/`. These may be aliases for the same collection; avoid
   reading it twice. The user supplies a name; locating the file is your job.
2. Read the matching file directly, including manual-only skills. This explicit
   dispatch does not change its automatic-loading settings. Resolve arguments and
   follow only that requested workflow and the references it requires.
3. If no matching skill exists, check `<name>.md` under an explicitly configured
   project-local command directory or the legacy `~/Notes/Prompts/commands/`
   directory, if present. Do not invent locations or recreate deleted commands.
4. If nothing matches, list available skill basenames and any configured legacy
   commands, report the missing workflow and stop.

## Examples

- `run-command review-changes` → read [review-changes](../review-changes/SKILL.md)
  directly and perform the review.
- `run-command are-you-sure` → read [are-you-sure](../are-you-sure/SKILL.md)
  directly and verify the recent changes.
- `run-command work-on-tasks priority 5` → read
  [work-on-tasks](../work-on-tasks/SKILL.md) directly, use the priority strategy and
  stop after at most five tasks.
