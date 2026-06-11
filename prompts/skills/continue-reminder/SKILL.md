---
name: continue-reminder
description: Resume a paused coding-agent session after a rate limit, cooldown, or scheduled break by using systemd user timers to send keystrokes to the correct tmux pane. Supports Claude, Codex, OpenCode, and AMP agents.
---

# Continue Reminder via Systemd

Use this skill when a coding agent running inside a tmux pane gets paused (rate-limited, user-throttled, or intentionally interrupted) and you want to **automatically resume** it at a known future time using systemd user timers and services.

## When to Use

- You hit a rate limit in a coding agent (e.g., Claude Code "session limit")
- You need to schedule a delayed `continue` or equivalent command
- The agent lives in a tmux pane and accepts keyboard input to resume
- You want the resume to happen automatically even if you step away
- You support multiple coding agents (Claude, Codex, OpenCode, AMP) and need per-agent specifics

## How It Works

1. **Inspect** the tmux pane where the agent is blocked.
2. **Note** the reset time / condition.
3. **Create** a systemd user timer that triggers at (or after) that time.
4. **Create** a oneshot service that runs a script sending the right keystrokes to the tmux pane.
5. **Enable** the timer; systemd wakes up and resumes the session automatically.

## Reference Files

Each coding agent has its own quirks (prompt text, resume command, key sequences). See the agent-specific sub-references below:

- [Claude](references/claude.md) — Claude Code CLI in tmux, rate-limit screen, `continue`
- [Codex](references/codex.md) — Placeholder for Codex CLI specifics
- [OpenCode](references/opencode.md) — Placeholder for OpenCode Agent specifics
- [AMP](references/amp.md) — Placeholder for AMP agent specifics

## Common Ingredients

These pieces are reused across all agent implementations:

| Component | Typical Path / Value |
|-----------|---------------------|
| TMUX socket | `/tmp/tmux-$(id -u)/default` |
| Script dir | `~/.local/bin/` |
| Service dir | `~/.config/systemd/user/` |
| Timer type | `OnCalendar` for wall-clock triggers |
| Service type | `oneshot` |

### Skeleton Script

```bash
#!/bin/bash
set -euo pipefail

TMUX_SOCKET="/tmp/tmux-$(id -u)/default"
TARGET="<session>:<window>.<pane>"

# 1) Acknowledge / select "stop and wait"
tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" Enter

# 2) Sleep past the reset window
sleep <buffer_seconds>

# 3) Send resume command
tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" "<resume_command>" Enter
```

### Skeleton Service

```ini
[Unit]
Description=Resume <agent> in tmux pane

[Service]
Type=oneshot
ExecStart=%h/.local/bin/<script>.sh
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
```

### Skeleton Timer

```ini
[Unit]
Description=One-off timer for <agent> tmux resume

[Timer]
OnCalendar=<ISO_datetime>
AccuracySec=1s
Persistent=false

[Install]
WantedBy=timers.target
```

### Enable / Check

```bash
systemctl --user daemon-reload
systemctl --user enable --now <timer>.timer
systemctl --user status <timer>.timer
```
