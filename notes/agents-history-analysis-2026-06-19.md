# Agent Run History Analysis — Skill Improvements

Date: 2026-06-19
Author: agent task 3k0
Source data: `~/Documents/Taskwarrior/AgentsHistory/tw-agent-export-*.json` (14 exports)
Skills cross-referenced: `~/.claude/skills/` → symlink to `~/Notes/Prompts/skills/`

## Method

The history is **not** raw transcripts; it is a series of Taskwarrior exports of
agent-managed tasks (the `+agent` tagged tasks driven by the `ask` CLI). Across
the 14 exports there are **240 unique completed tasks** (deduplicated by UUID)
carrying **963 annotations**. Annotations are the agents' own progress/result
notes plus the task specs injected by the orchestrator.

Projects represented:

| Project | Tasks |
|---------|-------|
| player  | 121   |
| ior     | 104   |
| conf    | 11    |
| others (scifi, dtail, goprecords) | 4 |

Friction was located by scanning all annotations for correction/retry/failure
keywords (retr, fail, wrong, assum, correct, revert, again, instead, blocked,
timeout, manual, workaround, ...) and then reading the matches in context and
cross-referencing them against the actual `SKILL.md` content.

The skill definitions live in `~/Notes/Prompts/skills/` (a separate git repo,
committed via the `commit-skills` skill), surfaced into Claude via the
`~/.claude/skills` symlink. **Skill edits therefore land in the Notes/Prompts
repo, not in this dotfiles repo.** This analysis only diagnoses and creates
follow-up tasks; it does not modify any skill.

## Findings (prioritized)

### 1. `agent-task-management` invoked as an `ask` subcommand — HIGH (follow-up 6q0)

The single most repeated signal. The same correction is injected verbatim into
many task descriptions (≥10 occurrences across ior tasks), e.g.:

> "Agent workflow: load the agent-task-management skill as instructions only,
> not as a shell command. Never run `~/go/bin/ask agent-task-management ...` or
> other natural-language `~/go/bin/ask` commands. Use only normal `~/go/bin/ask`
> subcommand syntax."

The current `SKILL.md` *already* warns about this (lines 10, 23-28: "It is not a
natural-language interface and does not understand skill names"), yet the
orchestrator still felt the need to repeat the warning in nearly every task.
That means the existing warning is not prominent or contractual enough to be
relied on. Concrete fix: hoist an explicit "Invocation contract" to the very top
of `SKILL.md` and into `references/00-context.md`, so the rule is seen at every
entry point and the per-task boilerplate can be dropped.

### 2. Workers stalling mid-edit, leaving broken/partial state — HIGH (follow-up 7q0)

Several tasks show a worker stalling part-way and a replacement having to revert
and resume:

- ior: "Previous agent stalled mid-refactor; partial uncommitted changes were reverted. Retrying with a fresh agent."
- ior: "Previous agent stalled mid-edit leaving broken model.go (undefined: streamRefreshMs, flameRefreshMs); reverted. Retrying."
- player j1: "Previous j1 worker errored due selected model capacity ... replacement worker should inspect current state, clean up leftover temp app/browser processes as needed, and resume from annotations."

There is no documented recovery procedure. `agent-task-management` should gain a
"recovering from a stalled/interrupted worker" section: how to detect partial
uncommitted edits (`git status`, build/compile check), revert cleanly to a
known-good baseline, clean up leftover temp processes, and resume from the task
annotations rather than from scratch.

### 3. Local toolchain cannot build/verify the project — HIGH (follow-up 8q0)

Agents repeatedly hit environments lacking the toolchain needed to verify their
own work, with inconsistent handling:

- ior: "Full go test blocked locally by missing libbpf header bpf/bpf.h."
- player (Flutter scaffold): "required Flutter verification is blocked locally: flutter and dart commands are not installed, so flutter analyze and flutter build apk --debug could not be run."

Sometimes the agent committed anyway with a clear annotation; the behavior should
be standardized. Add an env-preflight rule (in `go-best-practices` or a shared
reference): detect the missing toolchain early, run the smallest verifying subset
that *is* possible, annotate the blocker explicitly, and never claim full
verification when it could not be run.

### 4. Full test suites exceeding the test timeout — MEDIUM (follow-up 9q0)

The ior integration suite repeatedly exceeds the runner timeout:

- "Full suite still has intermittent integration flake behavior."
- "full `mage integrationTest` ran ... but the suite exceeded the 30m go-test timeout"
- "Full `mage integrationTest` intentionally not run due suite size"

Each agent re-derives which focused subset to run and how to phrase the
"full suite skipped" caveat. Document, in the build-system part of
`go-best-practices`, the canonical focused subset (e.g. `mage test`, `mage build`,
`TEST_NAME=... mage testWithName`), when skipping the full integration suite is
acceptable, and the required annotation wording so acceptance is unambiguous.

### 5. Pre-existing dirty worktree handling — MEDIUM (follow-up aq0)

Many player tasks repeatedly reasoned about the same unrelated dirty files:

- "left unrelated .gitignore and start.sh edits untouched."
- "Remaining unstaged changes are unrelated pre-existing .gitignore and start.sh edits."
- repo-split task: "noted pre-existing dirty files: start.sh ... (in scope, preserve) and .gitignore edits (likely unrelated, avoid committing unless required)."

The cost is re-deriving in-scope vs out-of-scope on every task. Add explicit
guidance to `references/3-complete-task.md`: at task start, snapshot `git status`,
classify each pre-existing change as in-scope or out-of-scope, never `git add -A`,
never commit unrelated files, and record the classification in an annotation.

### 6. Sub-agent edited an out-of-scope / vendored dependency — MEDIUM (follow-up bq0)

An ior sub-agent "fixed" a problem by editing a vendored dependency, which had to
be reverted:

- "modified ../libbpfgo/buf-ring.go to return <-chan error from Poll(), added replace directive in go.mod ..."
- "The sub-agent's fix modified libbpfgo itself and was reverted (commit 83d68e5). This task is not actionable without an upstream libbpfgo API change."

Add a "stay within task scope" rule to the sub-agent review / task workflow:
changes to upstream or vendored dependencies (and other clearly out-of-scope
files) must be flagged as a blocker / acknowledged limitation, not silently
patched.

### 7. `conf`/f3s r-node deploy mechanism is re-derived each task — LOW (follow-up cq0)

The `conf` project tasks repeatedly restate the same rollout contract:

> "changes MUST roll out to ALL r-nodes (r0, r1, r2) via the mechanism
> established in task o2. Verify after deploy: `systemctl status ...`,
> `journalctl -u ...`"

This worked well, but the mechanism (Rex `nfs_mount_monitor` task, idempotent
rollout to r0/r1/r2, post-deploy verification commands) lives only in task
annotations. Documenting it once in the `f3s` skill would let conf agents apply
it without re-derivation. (Positive signal: agents *did* update `f3s`/`storage.md`
during these tasks — that habit is working and should be preserved.)

## Follow-up agent tasks created

| ID  | Skill | Improvement |
|-----|-------|-------------|
| 6q0 | agent-task-management | Make the "not a natural-language interface" warning prominent + invocation contract |
| 7q0 | agent-task-management | Add "recovering from a stalled/interrupted worker" section |
| 8q0 | go-best-practices | Env-preflight: handle missing local toolchain, never claim unrun verification |
| 9q0 | go-best-practices | Long-running suite: focused subset + required skip annotation |
| aq0 | agent-task-management | Pre-existing dirty worktree: classify in/out of scope, never commit unrelated files |
| bq0 | agent-task-management | Sub-agent review: forbid out-of-scope/vendored-dep edits, flag as blocker |
| cq0 | f3s | Document the reusable r-node Rex deploy + verification mechanism |

These tasks are created with `+agent`; the skill changes themselves land in the
`~/Notes/Prompts/skills` repo, not in dotfiles.

## What is working well (keep)

- Agents consistently commit with descriptive messages and explicitly note when a
  task is intentionally *not* marked done per orchestrator instruction.
- The sub-agent review → fix → re-review loop catches real defects (e.g. PID-reuse
  mixing, podcast episode duplication) and is reflected in annotations.
- Documentation co-updates: `f3s`/`storage.md`, `AGENTS.md`, and `docs/api.md`
  are kept in sync with code changes within the same task.
