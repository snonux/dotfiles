# Orchestrating task batches

Use this reference only when selecting, delegating, reviewing, or progressing
through several tasks, including `/work-on-tasks`. It is the canonical home for
the parallelism rules and the memory guard; other references link here instead
of repeating them.

## Parallelism policy

Parallel tasks and parallel sub-agents are allowed **by default, with no fixed
cap**: run as many workers at once as is useful. Two things limit that:

1. **An explicit limit always wins.** If the user, the slash command, or the
   task itself states a limit ("at most 2 agents", "one at a time",
   "sequentially", "no parallel work"), follow it exactly and skip the rest of
   this policy that would exceed it.
2. **The memory guard** below, which protects the machine, not the task list.

Several tasks may be started (in progress) at the same time, one per parallel
worker. Multiple started tasks are therefore a normal state, not an error.

The orchestrator owns all implementation and review launches and all worker
accounting; task sub-agents must not spawn sub-agents.

### Do not parallelize conflicting tasks

Parallelism only helps when tasks are independent. Serialize (run one after the
other) tasks that:

- have a dependency relationship (`ask dep` / `depends:`; a blocked task is not
  in `ask ready` anyway),
- touch the same files or the same area, so their edits would collide or their
  builds/tests would interfere,
- share a resource that cannot be used twice at once (a port, a database, a
  single build directory, a generated file).

When two conflicting tasks must still overlap, isolate them instead: give each
worker its own git worktree (Agent `isolation: "worktree"`), then merge the
results in the orchestrator. With no isolation, all workers share one worktree,
so each worker must stage and commit **only its own files by explicit path**
(see "Commit only in-scope files" in [3-complete-task.md](3-complete-task.md));
never `git add -A`, `git add .`, or `git commit -a`, since those would sweep up
a sibling worker's half-finished edits.

## Memory guard

Before launching each additional sub-agent or worker, the orchestrator checks
available memory. Re-check whenever a running worker finishes and a slot could
be refilled. The numbers below are conservative defaults; the orchestrator may
tune them to the machine, but must keep the shape of the rule.

```bash
awk '/MemAvailable/ {printf "%d MiB available\n", $2/1024}' /proc/meminfo
awk '/MemTotal/ {printf "%d MiB total\n", $2/1024}' /proc/meminfo
free -m                       # also shows swap use
uptime; nproc                 # optional: load average vs. core count
```

Launch another worker only if **all** of these hold:

- `MemAvailable` is at least **2 GiB (2048 MiB)**, and
- `MemAvailable` is at least **15% of `MemTotal`**, and
- swap is not heavily in use (for example, used swap is below about 50% of
  total swap, and not growing between two checks), and
- optionally, the 1-minute load average is below the core count from `nproc`.

If any check fails, do **not** launch more workers. Let a running worker finish,
then re-check. If no worker is running and memory is still below the floor,
work directly in the orchestrator's context (one task at a time) rather than
launching anything.

Launch in small waves, not all at once:

- Launch one worker (or at most two), then wait for it to warm up, about 30 to
  60 seconds or until it has clearly started, before measuring again. A new
  agent's memory use only shows after it has loaded its context, started tools,
  and begun builds.
- Re-measure after every wave and apply the thresholds above again.
- Never launch heavy builds or full test suites in many workers at once. If
  tasks are known to be build-heavy (large compiles, `-race` suites, container
  or VM builds), stagger them, or run them one at a time regardless of free
  memory.

If memory pressure appears while workers are running (available memory falls
under the floor, swap starts growing, the machine gets sluggish), stop
launching new workers and let the running ones finish. Never kill user
processes, and do not stop a worker mid-edit to free memory.

## Selecting work

At the start and after every completed task, in this order:

1. Run `ask list start.any:`. **Resume all already-started tasks first** (in
   parallel, subject to the memory guard and the conflict rules above) before
   selecting anything new. Recovering a started task follows
   [6-recover-stalled-task.md](6-recover-stalled-task.md).
2. Only for the remaining free slots, select new tasks from `ask ready`, ordered
   by priority, then urgency, skipping tasks that conflict with anything already
   running. Run `ask start <id>` for each task as its worker begins.
3. When all started tasks are resumed and nothing more can be safely launched,
   wait for a worker to finish, then repeat.

Start new work in a fresh context to prevent implementation context from
drifting between tasks. The exception is a single task: when exactly one task is
started or ready, the orchestrator handles it directly in its own context. With
2 or more tasks to work on (started plus newly selected), delegate each to its
own sub-agent. The detailed rule is in [2-start-task.md](2-start-task.md).

## Per-task lifecycle

For each task, create it, start it, annotate progress, meet the completion
criteria, and have the orchestrator run fresh-context review(s) until one finds
no remaining issues. Commit the in-scope changes, mark the task done, then
check for the next started or ready task. The completion and review procedure
is in [3-complete-task.md](3-complete-task.md). Review sub-agents count as
workers: apply the memory guard before launching each reviewer as well.
