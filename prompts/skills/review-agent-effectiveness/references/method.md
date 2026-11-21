# Method: what to ask the data, and where it lies

Read this at step 4 of the skill.

## Questions that paid off

1. **Do agents read what we wrote?** Compare "skill files read per tool" for
   implementation agents and for reviewers with the files they are supposed
   to follow. In November 2026 no Codex implementation agent read the start
   or complete references, and reviewers opened a file about listing tasks
   because its name contained "review".
2. **What does loading cost?** "Skill words read per ask-using agent". The
   task annotation, not the skill, decided what was loaded.
3. **Where do commands get refused?** Compare tool error rates of worktree
   sub-agents with the others and read the error samples. Heredocs and
   scratch scripts were refused as "too complex to verify".
4. **How heavy is the bookkeeping?** `ask annotate` and `ask info` calls per
   finished task, and `ask info` output size.
5. **Which rules are broken, and by whom?** Sub-agents that ran `ask done`,
   pushed, spawned agents, ran `-race` or the full suite repeatedly, or used
   `git add -A`. Check whether the rule was in the prompt before blaming the
   agent.
6. **Where does a run stop?** Tasks started more than once, tasks left open,
   `ask stop` counts, and the user's messages about being blocked or slow.
7. **What does orchestration cost?** Waits and messages per launch, main
   session compactions, output tokens of orchestrators versus workers.
8. **Do reviews converge?** Review launches per finished task per week, and
   names containing a round number of three or more.
9. **Do small models cope?** The per-model table for pi: tool error rate,
   failed edits, `ask` error rate, tasks finished.
10. **Which commands do agents mistype?** The `?`-prefixed entries in "ask
    subcommand usage". cursor typed `ask show <id>` and similar about 280
    times; the fix was in the CLI (show the task, name the real
    subcommand), not in the skill text.
11. **Did the last changes work?** The `HEADLINE` lines for park calls,
    `last:` re-reads, notes on stop and done, and agents that read a card.

## Traps

- **Codex encrypts messages between agents.** Worker prompts are unreadable
  there; use commands, outputs and agent names.
- **An error is attributed to the whole command line.** `ask info x && go test`
  failing in the test still marks the `ask` call as failed. Trust the
  clustered error text, not the raw count.
- **Text inside annotations matches the `ask` pattern.** "ask subcommand
  syntax" in a note shows up as an unknown subcommand. Ignore the `?` entries
  that are obviously prose.
- **cursor-agent transcripts have no timestamps and no tool results.** Its
  error rates, durations, token counts and `ask info` sizes print "n/a"; do
  not read them as zero. Dates come from the file's modification time.
  Counts of commands, files read, sub-agent launches and prompts are
  reliable, and cursor's worker prompts are readable in full.
- **A cursor session can be a worker.** Some top-level cursor sessions start
  with a worker or reviewer prompt because another agent launched them; the
  scan counts those as sub-agents ("top-level worker").
- **Error samples are capped at 40 per agent**, so sampled totals are a floor.
- **Prompt checks see only the first 600 characters** of a worker prompt. "The
  prompt did not forbid it" cannot be concluded from the scan alone.
- **Active time excludes gaps over ten minutes**, so it is not wall time.
- **"Last 31 days" means files modified in that window**; long sessions that
  started earlier are included whole. pi is scanned in full by default.
- **"Skill words read" uses today's file sizes.** After shrinking files the
  same history yields a lower number; compare like with like.
- **A number is a lead, not a finding.** Reproduce it: the worktree project
  bug was confirmed by running `ask` inside a real linked worktree before any
  code was changed.

## Outside references

Comparing with a published agent workflow is a good way to start a review.
The first one used Uncle Bob's [ub-mode](https://github.com/unclebob/ub-mode):
its short imperative rules and deterministic tools (CRAP, duplication,
mutation) were worth copying; its hard thresholds as audit findings were not.
