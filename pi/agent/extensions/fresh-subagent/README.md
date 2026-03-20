# Fresh Subagent

Generic fresh-context delegation for Pi.

This extension gives Pi a simple subagent primitive:

- the main agent can call the `subagent` tool
- you can call `/subagent <prompt>` directly
- the delegated work runs in a new `pi --mode json -p --no-session` process
- the child starts with a fresh context
- the result comes back as one final answer

This is intentionally small. It does not manage agent catalogs, chains, or
parallel workers. It is meant for one-off delegation with a clean context.

## What It Is For

Subagents are generic. The main agent can hand them any focused prompt that
benefits from a clean context, for example:

- code review
- debugging
- focused research
- second-opinion architecture checks
- summarizing noisy output
- validating whether a task is really complete
- any other self-contained side task

One common use is the `taskwarrior-task-management` review loop:

1. The main agent implements the change
2. The main agent self-reviews the change
3. The main agent uses `subagent` for an independent fresh-context review
4. The main agent fixes findings
5. Only then does the task move toward completion

## Usage Flows

### Flow 1: Use it directly inside Pi

Run a direct delegation:

```text
/subagent Compare the current plan-mode extension behavior against the requested workflow and list only the mismatches.
```

Run a focused investigation:

```text
/subagent Find all code paths that write to the SSH known_hosts file and summarize the risk.
```

Run a review:

```text
/subagent Independently review the recent changes for bugs, regressions, and missing tests. Only report concrete findings.
```

### Flow 2: Use it from the main agent

Because this is registered as a tool, the main agent can call it itself.

Generic handoff pattern:

```text
Use the subagent tool for a fresh-context pass on this side task, then return only the useful result.
```

Review handoff pattern:

```text
First review your own changes. Afterwards, use the subagent tool to perform an independent fresh-context review and then address any findings.
```

Research handoff pattern:

```text
Use the subagent tool to inspect only the WireGuard setup path in a fresh context and summarize the concrete risks.
```

### Flow 3: Use it in one-shot CLI mode

This works outside the full TUI as well:

```bash
pi --model openai/gpt-4.1 --no-session -p '/subagent Say only SUBAGENT_COMMAND_OK'
```

### Flow 4: Use it in the Taskwarrior review loop

The intended task workflow is:

1. main agent implements
2. main agent self-reviews
3. main agent calls `subagent` for independent review
4. main agent fixes findings
5. only then complete the task

## What To Put In The Prompt

Subagents start fresh, so include enough context in the prompt:

- what to inspect or do
- the scope or files to focus on
- the expected output shape
- any constraints such as “report only concrete findings”

Good:

```text
/subagent Review the recent SSH bootstrap changes in hyperstack.rb. Report only concrete bugs, regressions, or missing tests.
```

Weak:

```text
/subagent Review this
```

## Notes And Limits

- The subagent uses a fresh session via `--no-session`.
- The subprocess still runs in the same working directory unless you override
  `cwd`.
- The extension disables itself inside child subagent processes to avoid
  accidental recursive registration.
- This is deliberately minimal. There is no built-in multi-agent orchestration,
  planner chain, or background pool here.
