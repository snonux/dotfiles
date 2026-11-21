# Cloud workers and worktree cleanup

Read this only when your harness offers cloud or remote agents, or when a
worker ran in its own git worktree. Otherwise skip it. The rest of the
orchestration rules are in [7-orchestrating-task-batches.md](7-orchestrating-task-batches.md).

## Cloud workers (optional)

If the harness offers cloud or remote agents (for example the Agent tool's
`isolation: "remote"`), the orchestrator **may** run suitable tasks there. It
is never required. Follow whatever the agent's own instructions say about when
to prefer cloud or local agents (a CLAUDE.md or AGENTS.md rule, for instance).
Without such guidance, use judgment: cloud workers save local memory and CPU
for long or build-heavy tasks, but each one needs a pushed starting point and
a fetch-and-verify round trip.

A task suits a cloud worker only when it needs nothing beyond the pushed
repository. Keep it local when it needs root/sudo, kernel access, local
hardware or devices, local-only toolchains or sibling checkouts, local services,
or private data that must not leave the machine. Cloud workers also cannot
start from unpushed local commits, so the base the task needs must already be
on the remote, or pushing it must be allowed under the project's rules.

A cloud worker cannot reach `ask`, so the orchestrator adapts the worker prompt:

- paste the output of `ask info <id>` into the prompt after the card, and tell
  the worker that it cannot run `ask`: rules 1, 2, 9 and 10 of the card
  become "report this in your final summary" instead;
- tell the worker that rule 7's "no push" is replaced for it: it commits on
  its own branch and pushes **that branch only**, never the default branch.
  Ask it to end with a summary
  of what it changed, how it proved the change (including the red-first test
  output), and anything left open;
- all other rules of the card apply.

When the worker returns, the orchestrator fetches the branch, records the
worker's summary with `ask annotate`, runs any checks that need the local
machine, merges, and continues with the normal review and completion steps.
The memory guard does not apply to cloud workers (they use no local memory),
but an explicit concurrency limit still counts them. If cloud agents are
unavailable or fail to start, fall back to local workers without asking.

## Worktree cleanup

At the end of a batch, clean up the worktrees and branches that the run's
workers created (Agent `isolation: "worktree"` leaves a worktree behind when
it changed something):

```bash
git worktree list
git worktree prune            # drops entries whose directories are gone
```

For each worker worktree: if it is clean and its branch is merged into the
current branch, remove it (`git worktree remove <path>`) and delete the branch
(`git branch -d <branch>`). A worktree with uncommitted changes, or a branch
that is not merged, is someone's unfinished work: leave it and list it in the
final report for the user to decide. Never use `--force`. Remote branches
pushed by cloud workers are listed in the report too. Delete them only when
they are merged and the agent's instructions or the user allow it.
