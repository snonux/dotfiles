---
name: review-agent-effectiveness
description: "Measure how coding agents (Claude Code, Codex CLI, pi, cursor-agent) actually used the task, audit and review skills in recent session history, compare with the last baseline, and improve the skills, the ask CLI and the pi extension accordingly. Use only when explicitly invoked as review-agent-effectiveness. Triggers on: review agent effectiveness, analyse session history, agent workflow review, skill usage analysis."
disable-model-invocation: true
---

# Review Agent Effectiveness

Find out what agents really did with the workflow skills, then change the
skills and tools so the next month goes better. Evidence first: every
suggestion needs a number from the scan or a message the user typed.

**Privacy:** session logs are private. Run everything on this machine. No
cloud agents, no uploads, and no raw user text in any file inside a
repository or in a commit message.

## Steps

1. **Scan** (about a minute, writes outside any repository):

   ```bash
   cd "$SCRATCH"    # a temporary directory, never a repository
   python3 -I ~/.agents/skills/review-agent-effectiveness/scripts/scan_sessions.py
   ```

2. **Report.** Read the `HEADLINE` block first and compare each line with the
   newest baseline in `references/` (first one:
   [baseline-2026-11.md](references/baseline-2026-11.md)):

   ```bash
   python3 -I ~/.agents/skills/review-agent-effectiveness/scripts/report_sessions.py scan.jsonl
   ```

3. **Read what the user typed** in those sessions. Numbers show how often;
   these messages show what hurt:

   ```bash
   python3 -I ~/.agents/skills/review-agent-effectiveness/scripts/steering_messages.py scan.jsonl --since <date of last baseline>
   ```

4. **Dig into the three or four largest signals** before concluding. Open
   real examples behind each number, and reproduce tool problems by hand.
   The questions that paid off before, and the traps in the data, are in
   [references/method.md](references/method.md).

5. **Write findings, then suggestions**, most valuable first. For each: the
   evidence, the change, and where it lives. Prefer, in this order: fix the
   tool, shorten a card, move text behind a trigger, add text. Present them
   and let the user choose before changing anything.

6. **Apply** what the user approved. Where each thing lives and how it is
   released: [references/where-things-live.md](references/where-things-live.md).

7. **Verify and record.** Run the skill audit script, the tools' tests, then
   save the new `HEADLINE` block as `references/baseline-<YYYY-MM>.md` with
   one paragraph on what was changed. Commit and push with `commit-skills`.

## Scripts

- `scripts/scan_sessions.py`: streams the session logs of Claude Code, Codex
  CLI, pi and cursor-agent into one JSON record per session file
  (`scan.jsonl`). Options: `--days` (Claude Code and Codex, default 31),
  `--pi-days` and `--cursor-days` (default: all), `--out`.
- `scripts/report_sessions.py`: aggregate numbers, no user text. The
  `HEADLINE` block is what gets compared between runs.
- `scripts/steering_messages.py`: prints raw user messages for local
  reading. Terminal only.
