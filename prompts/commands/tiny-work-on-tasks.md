# /tiny-work-on-tasks

**Description:** Work on one small task with a short `ask` workflow for limited contexts.

---

## Prompt

Work on exactly one small task in the current project. Keep this workflow concise:

1. Run `ask list start.any:`. If exactly one task is started, resume it. If more than one is started, report their IDs and stop.
2. Only when none is started, run `ask ready limit:10`, choose one small unblocked task, read it with `ask info <id>`, and start it with `ask start <id>`.
3. Make the smallest change that completes the task and run the relevant validation.
4. Record the result with `ask annotate <id> "<what changed and how it was checked>"`.
5. When the task is complete and checked, run `ask done <id>`.

Do not start another task in this run. Report the task ID, the change made, and the validation result.
