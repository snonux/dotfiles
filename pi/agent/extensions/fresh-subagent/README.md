# Fresh Subagent

Minimal fresh-context subagent support for Pi.

## What it does

- registers a `subagent` tool the main agent can call
- registers a `/subagent <prompt>` command for direct use
- runs the delegated work in a new `pi --mode json -p --no-session` process
- defaults to the current session model when one is active
- returns only the final answer or review result

This is intentionally small. It does not manage agent catalogs, chains, or
parallel workers. It is meant for one-off delegation with a clean context.

## What it is for

Subagents are generic. The main agent can hand them any focused prompt that
benefits from a clean context, for example:

- independent code review
- fresh-context debugging
- focused codebase research
- second-opinion architecture checks
- summarizing a noisy command output or diff
- validating whether a completed task is actually done

One common use is the `taskwarrior-task-management` review loop:

1. The main agent implements the change
2. The main agent self-reviews the change
3. The main agent uses `subagent` for an independent fresh-context review
4. The main agent fixes findings
5. Only then does the task move toward completion

## Direct usage

Run a manual fresh-context review:

```text
/subagent Independently review the recent changes for bugs, regressions, and missing tests. Only report concrete findings.
```

Run a focused side investigation:

```text
/subagent Find all code paths that write to the SSH known_hosts file and summarize the risk.
```

Run a generic delegation:

```text
/subagent Compare the current plan-mode extension behavior against the requested workflow and list only the mismatches.
```

One-shot CLI usage also works now:

```bash
pi --model openai/gpt-4.1 --no-session -p '/subagent Say only SUBAGENT_COMMAND_OK'
```

## Agent usage

Because this is registered as a tool, the main agent can call it itself. A good
generic pattern is:

```text
Use the subagent tool for a fresh-context pass on this side task, then return only the useful result.
```

For review-specific flows:

```text
First review your own changes. Afterwards, use the subagent tool to perform an independent fresh-context review and then address any findings.
```

## Notes

- The subagent uses a fresh session via `--no-session`.
- The subprocess still runs in the same working directory unless you override
  `cwd`.
- The extension disables itself inside child subagent processes to avoid
  accidental recursive registration.
