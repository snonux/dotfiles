# Baseline: 2026-11-21

Scan of Claude Code and Codex CLI sessions modified in the 31 days before
2026-11-21, all pi sessions since May 2026 (2,788 session files, about
7 GB), and all cursor-agent transcripts since March 2026 (743 files, most
from September and October). The next review compares its `HEADLINE` block with this one.

## HEADLINE (before the changes below)

```text
claude sub-agents: 1002
claude skill words read per ask-using agent: 568
claude share of ask-using sub-agents reading 2-start-task.md: 0.008
claude tool error rate % worktree sub-agents: 5.1
claude tool error rate % other sub-agents: 2.4
claude sub-agents that ran ask done: 61
claude sub-agents that spawned agents: 41
claude ask annotate per finished task: 4.02
claude median ask info output chars: 3278
claude median minutes ask start to ask done: 36.5
codex sub-agents: 1036
codex skill words read per ask-using agent: 3125
codex share of ask-using sub-agents reading 2-start-task.md: 0.055
codex tool error rate % worktree sub-agents: n/a
codex tool error rate % other sub-agents: 5.6
codex sub-agents that ran ask done: 1
codex sub-agents that spawned agents: 28
codex ask annotate per finished task: 6.72
codex median ask info output chars: 3864
codex median minutes ask start to ask done: 29.1
cursor sub-agents: 430
cursor skill words read per ask-using agent: 1753
cursor share of ask-using sub-agents reading 2-start-task.md: 0.083
cursor tool error rate % worktree sub-agents: n/a
cursor tool error rate % other sub-agents: n/a
cursor sub-agents that ran ask done: 24
cursor sub-agents that spawned agents: 0
cursor ask annotate per finished task: 5.58
cursor median ask info output chars: n/a
cursor median minutes ask start to ask done: n/a
pi sessions: 512
pi ask annotate per finished task: 2.11
pi share of commits using git add -A: 0.462
all ask park calls: 0
all share of ask info calls using last:: 0.000
all share of ask stop calls with a note: 0.063
all share of ask done calls with a note: 0.127
all agents that read a card file: 0
```

The Claude Code and Codex "skill words read" lines were computed with the
file sizes of that day, before the files were shortened; the cursor line was
computed after. cursor-agent transcripts carry no timestamps or tool
results, hence the "n/a" lines.

## Other numbers worth re-checking

| Measure | Value |
|---|---|
| Codex implementation agents that read the start or complete reference | 0 of 86 |
| Codex review agents that read the task-listing reference instead of the completion one | 131 of 500 (49 read the right one) |
| Commands refused inside Claude Code worktree agents | at least 1,167, in 221 of 229 agents |
| `ask info` output, Codex: median / 90th percentile / maximum characters | 3,864 / 16,956 / 59,760 |
| `ask info` calls per task, Codex: median / maximum | 4 / 77 |
| `-race` runs by Claude Code sub-agents (most by one agent) | 1,240 (52) |
| Claude Code sub-agents that pushed | 171 |
| Codex tasks started more than once / left open in the session | 60 / 82 |
| Codex orchestrator wait and sleep calls for 1,264 launches | 5,746 |
| Codex orchestrator share of all Codex output tokens | about half (23.6M) |
| Review launches per finished task, Codex, mid-October then late October | 2.9 then about 1 |
| cursor-agent: mistyped info commands (`ask show <id>`, `notes`, `task`, `tasks`, `annotations`, `get`, `status`) | about 280 |
| cursor-agent: full test suite runs by sub-agents | 148 by 430 sub-agents |
| cursor-agent: sessions using `ask` / tasks finished in the session | 304 / 258 |

## What was changed on 2026-11-21

- **Role cards.** Worker, reviewer and orchestrator cards of at most 200
  words each, pasted into sub-agent prompts; all other task references load
  only on a stated trigger. The standard task annotation no longer tells
  every agent to load several skills.
- **`ask` v0.45.1.** `show <id>` and similar words now print the task
  instead of failing. From v0.45.0: `info <id> last:<n>`, an optional note on `stop` and
  `done`, `park` / `unpark` / `parked` with parked tasks hidden from `ready`,
  linked worktrees use the main checkout's project, a lone unknown word is
  refused instead of becoming a task.
- **Workflow rules.** Test first with a `Red first:` annotation; one
  annotation per milestone; park and continue instead of stopping at a
  blocker; a `Handoff:` note when stopping unfinished; worktree workers use
  the edit tools and simple commands; the swap condition left the memory
  guard; optional batch reviews; a status line after each closed task.
- **Tools.** `gocrap` and `crap-check.sh` give the reviewer a pass/fail exit
  code for the functions a change touched.
- **pi.** The `agent-plan-mode` prompt follows the worker card.
- **Size budget.** The skill audit script warns above 200 words for cards
  and 1,500 for other skill files.

## First live run of the cards (2026-11-21)

A four-task Go test project, run with Sonnet sub-agents and `ask` v0.45.1.
An orchestrator followed the orchestrator card; three workers and two
reviewers got only their pasted card. Then one Sonnet agent ran
`work-on-tasks` alone, with no sub-agents, for the last two tasks.

| Check | Result |
|---|---|
| Tasks finished / parked correctly | 4 of 4 finished; the task that needed a decision was parked with a one-line question, and the run stopped while its dependent waited |
| Tool errors across 6 agents | 0 |
| Skill files read by workers and reviewers | none beyond the pasted card (reviewers ran `crap-check.sh`) |
| Skill files read by the solo agent | `work-on-tasks/SKILL.md`, the three cards, `8-blocked-and-handoff.md` |
| `ask info` calls per agent and task | 1 |
| Workers running `ask start`, `ask done`, push, or sub-agents; `git add -A` | none |
| `Red first:` annotation and commit message with why, what, proof | every task |
| `ask` inside a linked worktree | worked (one worker ran there) |
| Review rounds | 1 per task, all PASS |
| Time per task | 13 to 34 seconds per worker, 12 to 17 per reviewer |

One slip: a worker ran `-race` three times where the card said once. Rule 4
of the worker card was reworded afterwards ("While working: only your own
tests, no `-race`"). The harness's refusals of complex commands inside
harness-isolated worktrees were not exercised, because the test worktree was
created by hand outside the session's repository.

## What should move by the next review

- Skill words read per agent: well below 1,000 for Codex.
- Agents that read a card file, `ask park` calls, and `last:` re-reads:
  above zero and growing.
- Worktree sub-agent error rate: close to the rate of other sub-agents.
- `ask annotate` per finished task: about 2 to 3.
- Sub-agents running `ask done`, pushing, or spawning agents: near zero.
- pi commits using `git add -A`: well below 46%.

If a number did not move, check first whether agents saw the rule at all
(question 1 in [method.md](method.md)) before rewriting it.
