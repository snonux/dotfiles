---
name: continue-reminder
description: "Resume a paused coding-agent session after a rate limit, cooldown, or scheduled break by using systemd user timers to send keystrokes to the correct tmux pane. Supports Claude, Codex, OpenCode, and AMP agents. Use when a session hit a rate or session limit and should continue by itself later. Triggers on: continue reminder, resume after rate limit, session limit, schedule continue, resume agent later."
disable-model-invocation: true
---

# Continue Reminder via Systemd

Use this skill when a coding agent running inside a tmux pane gets paused (rate-limited, user-throttled, or intentionally interrupted) and you want to **automatically resume** it at a known future time using systemd user timers and services.

Two modes:

- **One-shot delayed resume** — the agent shows a reset time (Claude rate-limit menu); a timer fires once after it.
- **Recurring stall watch** — the agent stalls with no fixed reset time and may re-stall on every turn (e.g., Codex `Selected model is at capacity. Please try a different model.`); a recurring timer checks the pane every N minutes and resumes it when safe.

## When to Use

- You hit a rate limit in a coding agent (e.g., Claude Code "session limit")
- You need to schedule a delayed `continue` or equivalent command
- The agent repeatedly stalls with a capacity message (e.g., Codex) and should resume itself whenever it is safe
- The agent lives in a tmux pane and accepts keyboard input to resume
- You want the resume to happen automatically even if you step away
- You support multiple coding agents (Claude, Codex, OpenCode, ampcode) and need per-agent specifics

## How It Works

1. **Inspect** the tmux pane where the agent is blocked.
2. **Note** the reset time / condition.
3. **Create** a systemd user timer that triggers at (or after) that time.
4. **Create** a oneshot service that runs a script sending the right keystrokes to the tmux pane.
5. **Enable** the timer; systemd wakes up and resumes the session automatically.

## Recurring Stall Watch (no reset time known)

When the block may recur on every turn and has no advertised reset time, build a recurring watcher instead of a one-shot timer:

1. **Timer**: `OnCalendar=*:0/30` (or `OnUnitActiveSec=30min`) still triggering a `oneshot` service — the service is simply re-run each time.
2. **Script per check** — capture the pane (visible screen plus a little scrollback), then gate on state, in order:
   - busy indicator visible (e.g. `esc to interrupt` for Codex) → do **nothing**;
   - stall message visible **and** idle input placeholder visible → send the resume command + `Enter`;
   - the resume command sitting unsubmitted in the input box → press `Enter` alone;
   - anything else (e.g. a user draft in the input box) → do nothing.
3. **Resend guard**: keep a per-pane state file with a minimum interval (e.g. 10 min) so manual reruns cannot double-send.
4. **Target panes by `pane_current_command`**, never hardcoded pane indices — panes get renumbered.

Worked example (Codex capacity watcher on the homelabfs session): [references/codex.md](references/codex.md).

## Reference Files

Each coding agent has its own quirks (prompt text, resume command, key sequences). See the agent-specific sub-references below:

- [Claude](references/claude.md) — Claude Code CLI in tmux, rate-limit screen, `continue`
- [Codex](references/codex.md) — Codex CLI in tmux: capacity stall (`Selected model is at capacity`), idle/busy gating, `continue` resume, recurring 30-min watcher
- [OpenCode](references/opencode.md) — Placeholder for OpenCode Agent specifics
- [ampcode](references/amp.md) — Placeholder for ampcode agent specifics

## Common Ingredients

These pieces are reused across all agent implementations:

| Component | Typical Path / Value |
|-----------|---------------------|
| TMUX socket | `/tmp/tmux-$(id -u)/default` |
| Script dir | `~/.local/bin/` |
| Service dir | `~/.config/systemd/user/` |
| Timer type | `OnCalendar=<ISO_datetime>` for one-shot resumes; `OnCalendar=*:0/30` (or `OnUnitActiveSec`) for recurring watches |
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
