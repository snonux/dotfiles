# OpenCode Agent — Continue Reminder

> **PLACEHOLDER** — This reference has not been populated yet because the OpenCode agent was not active in the originating session.

## Known Differences from Claude

| Aspect | Expected Behavior |
|--------|-------------------|
| Rate-limit screen | Unknown; OpenCode may throttle differently |
| UI paradigm | May be chat-based rather than menu-based |
| Resume command | Unknown; likely not `continue` |
| Integration | May run outside tmux (e.g., VS Code extension or standalone binary) |

## TODO

1. Identify how OpenCode signals a pause / rate limit:
   - Does it print a message in the terminal?
   - Does it spawn an interactive prompt?
   - Is there a headless mode that behaves differently?

2. If OpenCode runs in tmux, capture the pane state and record:
   - Pause / limit indicator text
   - Required keystrokes to acknowledge
   - Resume command or hotkey

3. If OpenCode runs outside tmux (e.g., via LSP or IDE), determine whether:
   - `tmux send-keys` is still viable (IDE integrated terminal)
   - An alternative IPC mechanism is needed (API, file watcher, signal)

4. Update this file with a concrete example mirroring the Claude reference structure.
