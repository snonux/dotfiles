# Recover a stalled or interrupted worker

Use with `00-context.md`. Project name and global rules apply.

A prior worker (sub-agent or session) may have stalled or been interrupted
**mid-edit**, leaving the worktree with broken, uncommitted, partial changes. A
replacement worker must clean up before resuming — otherwise it builds on a
corrupt state. This is the recovery procedure: **detect → assess → revert →
resume**.

This applies whenever you pick up a task that was already `start`ed but not
`done` (see `2-start-task.md`). Always check for a stalled-worker situation
before assuming the worktree is clean.

## 1. Detect a partial / interrupted edit

Signs the previous worker did not finish cleanly:

- **Dirty worktree you did not create** — `git status --short` shows modified,
  added, or deleted files, but the current context has made no edits.
- **Broken build or syntax** — the project fails to compile, or a quick
  `git diff` shows half-applied edits (truncated functions, unbalanced braces,
  duplicated blocks, leftover conflict markers).
- **Task started but not done** — `ask info <id>` shows it started, and the
  latest annotations describe work in progress that does not match the
  committed state.

```bash
git status --short            # what is dirty
git diff                      # inspect the actual changes
git log --oneline -5          # find the last committed (known-good) state
```

## 2. Assess against the annotations

Before touching anything, **read the task's annotations** to learn what the
prior worker reported doing (see `4-annotate-update-task.md`):

```bash
ask info <id>
```

Use the annotations to classify the dirty changes:

- **In-scope WIP worth keeping** — coherent, on-task edits the prior worker
  reported and that still make sense. Keep and finish these.
- **Broken / half-applied edits to discard** — corrupt, contradictory, or
  abandoned edits. Revert these to the last known-good state.
- **Unrelated user changes** — edits that are *not* part of this task (the
  user's own work). **Never** discard these. Leave them untouched.

If you cannot tell which bucket a change belongs to, treat it as
keep-and-inspect rather than discarding it.

## 3. Revert cleanly to a known-good state

The known-good state is the last commit (`git log --oneline -5`). Revert
**only** the broken in-scope edits; preserve unrelated user changes and any WIP
worth keeping.

- **Discard a specific broken file** (back to last commit):

  ```bash
  git checkout -- path/to/broken_file
  ```

- **Set aside everything to inspect safely** without losing it — stash, so
  nothing is destroyed and you can restore selectively:

  ```bash
  git stash push -m "stalled-worker WIP for <id>" path/to/file ...
  git stash show -p stash@{0}     # review before deciding
  git stash pop                   # restore if it was worth keeping
  git stash drop                  # discard only after confirming it is junk
  ```

- **Keep WIP worth keeping** — leave those files as-is and continue from them.

Do **not** use `git checkout -- .`, `git reset --hard`, or `git clean -fd`
blindly: they destroy unrelated user changes too. Scope every revert to the
specific broken files. Cross-reference the commit discipline in
`3-complete-task.md` — recovery ends with the same clean, committed state any
completed task requires.

## 4. Resume

1. **Re-read** the description and all annotations (`ask info <id>`) so you
   resume with full context, not just the diff.
2. **Redo from the last known-good point** — continue from the last commit (or
   the kept WIP), redoing only what was lost. Follow the normal task flow.
3. **Annotate the recovery** so the history is honest and the next worker
   understands what happened:

   ```bash
   ask annotate <id> "Recovered from stalled worker: discarded broken edits in <files>, kept <WIP>, resuming from commit <hash>."
   ```

4. Finish the task under the usual completion criteria in
   `3-complete-task.md` (compiles, tests pass, committed to git).

## Conventions

- When picking up an already-started task, check for a stalled-worker situation
  before assuming a clean worktree.
- Always assess dirty changes against the annotations before reverting.
- Scope every revert to specific broken files; never destroy unrelated user
  changes with blanket `reset --hard` / `clean` / `checkout -- .`.
- Prefer `git stash` (recoverable) over `git checkout --` (destructive) while
  you are still deciding what is junk.
- Always annotate the recovery, then resume under the normal completion
  criteria.
