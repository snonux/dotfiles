# Codex CLI — Continue Reminder

> **PLACEHOLDER** — This reference has not been populated yet because Codex CLI was not active in the originating session.

## Known Differences from Claude

| Aspect | Expected Behavior |
|--------|-------------------|
| Rate-limit screen | May differ; verify by capturing the tmux pane |
| Menu confirmation | May require `Enter` or a different key |
| Resume command | Likely **not** `continue`; inspect the prompt text |
| Session ID | Typically tied to a `codex` tmux session name |

## TODO

1. Capture a Codex rate-limit screen in a tmux pane and record:
   - Exact prompt text
   - Available options / key bindings
   - Reset time format and timezone
   - Correct resume command (e.g., `resume`, `go`, `y`, etc.)

2. Update this file with a concrete example mirroring the Claude reference structure:
   - Scenario
   - Steps Taken
   - Verification commands
   - Key Details table

3. Update `../SKILL.md` if Codex requires a fundamentally different approach (unlikely, but possible).
