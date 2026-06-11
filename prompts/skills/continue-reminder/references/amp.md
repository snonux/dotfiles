# AMP Agent — Continue Reminder

> **PLACEHOLDER** — This reference has not been populated yet because the AMP agent was not active in the originating session.

## Known Differences from Claude

| Aspect | Expected Behavior |
|--------|-------------------|
| Rate-limit screen | Unknown; AMP may handle throttling server-side |
| UI paradigm | Unknown; could be TUI, web UI, or API-driven |
| Resume command | Unknown |
| Session model | AMP might use long-running processes or ephemeral workers |

## TODO

1. Clarify what "AMP" refers to in this context:
   - **Amplify** (AWS)?
   - **AIX MP** (IBM)?
   - A proprietary/multi-agent coding harness?
   - Something else?

2. Determine AMP's runtime environment:
   - Does it run in a tmux pane?
   - Is it daemonized?
   - Does it expose a CLI that can be scripted?

3. If AMP has a resumable terminal session, capture the pane state and record:
   - Pause / limit indicator text
   - Keystrokes or commands required to resume

4. Update this file with a concrete example mirroring the Claude reference structure.
