# ampcode Agent — Continue Reminder

> **PLACEHOLDER** — This reference has not been populated yet because the ampcode agent was not active in the originating session.

## Known Differences from Claude

| Aspect | Expected Behavior |
|--------|-------------------|
| Rate-limit screen | Unknown; ampcode may handle throttling server-side |
| UI paradigm | Unknown; could be TUI, web UI, or API-driven |
| Resume command | Unknown |
| Session model | ampcode might use long-running processes or ephemeral workers |

## TODO

1. Determine ampcode's runtime environment:
   - Does it run in a tmux pane?
   - Is it daemonized?
   - Does it expose a CLI that can be scripted?

2. If ampcode has a resumable terminal session, capture the pane state and record:
   - Pause / limit indicator text
   - Keystrokes or commands required to resume

3. Update this file with a concrete example mirroring the Claude reference structure.
