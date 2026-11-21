# Commit only in-scope files

Read this when `git status` showed changes before the task started, or when
several workers share one working tree. Otherwise `git add <explicit paths>`
from the worker card is all you need.

## Pre-existing dirty worktree

The worktree may already be dirty **before this task starts** — e.g. the user's
own unrelated edits to `.gitignore`, `start.sh`, or other files. Those changes
are **not yours to commit**. (This is distinct from a *stalled worker* that left
broken, half-applied edits mid-task — for that, see `6-recover-stalled-task.md`.
Here the dirty changes are intact, unrelated user work, not corruption.)

To avoid committing unrelated files (with parallel workers sharing one worktree,
a sibling worker's in-progress edits are also out-of-scope for you):

1. **At task start, and again before committing, run `git status`** and classify
   every dirty path:

   - **In-scope** — files this task created or modified. These get committed.
   - **Out-of-scope** — pre-existing or unrelated changes (the user's own work).
     These get **left exactly as they were**.

   ```bash
   git status --short            # full picture of what is dirty
   ```

2. **Stage only the in-scope files by explicit path.** Never blanket-add when the
   worktree had pre-existing unrelated changes:

   ```bash
   git add path/to/changed_file path/to/other_changed_file   # explicit paths only
   ```

   Do **not** use `git add -A`, `git add .`, or `git commit -a` here — they would
   sweep up the user's unrelated edits into your commit.

3. **Never commit unrelated files.** Leave out-of-scope changes untouched in the
   worktree; do not stage, commit, revert, or stash them.

4. **Record the in-scope/out-of-scope decision in an annotation** so the history
   is honest and the next worker knows what was deliberately left alone (see
   `4-annotate-update-task.md`):

   ```bash
   ask annotate <id> "Committed in-scope: <files>. Left out-of-scope: <files>."
   ```

If you cannot confidently tell whether a dirty file is in-scope, treat it as
out-of-scope and leave it alone rather than risk committing the user's work.
