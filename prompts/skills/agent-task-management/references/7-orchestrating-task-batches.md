# Orchestrating task batches

Use this reference only when selecting, delegating, reviewing, or progressing
through several tasks, including the manual [work-on-tasks skill](../../work-on-tasks/SKILL.md). It is the canonical home for
the parallelism rules and the memory guard; other references link here instead
of repeating them.

Most of the time [card-orchestrator.md](card-orchestrator.md) is enough. This
file is the detail behind it: read the section you need. Cloud workers and
worktree cleanup are in [7b-cloud-workers-and-worktrees.md](7b-cloud-workers-and-worktrees.md).

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
(see [3c-commit-in-scope.md](3c-commit-in-scope.md));
never `git add -A`, `git add .`, or `git commit -a`, since those would sweep up
a sibling worker's half-finished edits.

## Memory guard

The guard protects the machine, not the task list. Check **once before each
wave** of local launches (not before every single launch), and again when a
finished worker frees a slot:

```bash
awk '/MemAvailable/ {a=$2} /MemTotal/ {t=$2} END {printf "%d MiB available, %d%% of total\n", a/1024, 100*a/t}' /proc/meminfo
```

Launch another local worker only if `MemAvailable` is at least **2 GiB** and
at least **15% of total**. Swap use is not a criterion: on a machine that has
been up for a while, old pages stay in swap long after the pressure is gone,
and waiting on it stalled runs for no benefit.

If the check fails, launch nothing and let a running worker finish. If no
worker is running and memory is still below the floor, work one task at a
time in the orchestrator's own context.

- Launch one or two workers, wait 30 to 60 seconds for them to load their
  context and start builds, then measure again.
- Cap build-heavy workers (large compiles, `-race` suites, emulators,
  container or VM builds) at about one per two cores, even when memory
  allows more. Other sessions count too: if `uptime` shows a load average
  well above the core count, hold build-heavy workers until one of yours
  finishes; light workers (reviews, small script fixes) can still start. Oversubscription causes timeouts and flaky tests that cost
  more than the parallelism saves.
- If the machine gets sluggish while workers run, stop launching and let
  them finish. Never kill user processes, and never stop a worker mid-edit
  to free memory.

Cloud workers use no local memory, so the guard does not apply to them, and
they are preferred over local workers whenever the harness offers them and
the task suits one
([7b-cloud-workers-and-worktrees.md](7b-cloud-workers-and-worktrees.md)).

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

## Worker prompt

The prompt for every task worker is short and fixed:

1. the task ID and a one-line summary;
2. the absolute path of the project root, and whether the worker runs in its
   own git worktree;
3. the full text of [card-worker.md](card-worker.md), pasted in.

After the card, add what only you know about this task:

- **where the worker's shell starts.** If it is not the project root (a task
  in another repository), say so and tell it to begin commands with
  `cd <root> &&`; `ask` only finds the task from inside its project;
- **what must not be touched for real:** the live service, device, account or
  data the code talks to, and what to use instead (the fakes the tests use);
- **for a reviewer of a task without a code diff** (an audit, a chore across
  repositories, a deployment, retaken pictures): what the deliverable is and
  where to find it, and the two or three things most likely to be wrong.

Paste the card rather than telling the worker to go and read files. Session
history showed that workers act on the prompt and the task annotations and
rarely open the references, so a rule that is not in the prompt is usually
not followed. Add task-specific constraints after the card (for example "do
not touch tools/integration; another worker owns it"). Reviewers get
[card-reviewer.md](card-reviewer.md) the same way, plus the task ID, the base
commit, and the round number.

## Per-task lifecycle

For each task, create it, start it, annotate milestones, meet the completion
criteria, and have the orchestrator run fresh-context review(s) within the
review budget (at most two rounds; the second only for blocking findings; see
[3d-review-budget.md](3d-review-budget.md)).
Commit the in-scope changes, mark the task done, then check for the next
started or ready task. Close each task as soon as it meets its criteria; do not
hold finished tasks back for one big final merge or gate run. When lanes are
merged into a shared branch, merge each finished lane promptly, run the full
gates on the merged result, and close the tasks it covers.

Workers run only the targeted checks for their task (formatting, lint when
code changed, the filtered tests and end-to-end drivers for their feature).
Heavy full-suite runs happen once per merge in the orchestrator, not in every
worker. On a small host, cap concurrent build-heavy workers (about one per two
cores) even when memory would allow more: oversubscription slows every worker
and causes timing flakes that cost more review and rerun time than the
parallelism saves. The completion and review procedure
is in [3-complete-task.md](3-complete-task.md). Review sub-agents count as
workers for the per-wave memory guard.

If the user explicitly asked to skip reviews (to speed up the batch), launch no
review sub-agents: each task goes from its self-review straight to commit and
`ask done <id>`. Tell every implementation sub-agent about the opt-out so it
does not wait for a reviewer. See [3d-review-budget.md](3d-review-budget.md), which also covers batch reviews.

## Status line and stop conditions

After each closed task, print one line so a person glancing at the session
sees progress without asking:

```text
Status: 12 done, 2 running, 1 parked, 5 ready
```

A task that needs a human is parked (`ask park <id> "<question>"`), not a
reason to stop: take the next task. Stop the run only when every remaining
task is parked or waits on a parked one, when a stated limit is reached, or
when the user says so. The final report lists the done tasks, the open
questions from `ask parked`, worktrees or branches left for the user, and
anything unpushed. Details: [8-blocked-and-handoff.md](8-blocked-and-handoff.md).
