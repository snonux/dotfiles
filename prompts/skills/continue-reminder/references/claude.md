# Claude Code CLI — Continue Reminder

Concrete example: Claude Code CLI running in a tmux pane hits a **session rate limit** and presents a `/rate-limit-options` menu.

## Scenario

- tmux session: `ior`
- Window: `0`
- Pane: `0.0` (Claude Code blocked)
- Message: *"You've hit your session limit · resets 1:10pm (Europe/Sofia)"*
- Menu option 1: **"Stop and wait for limit to reset"**
- Resume command after reset: **`continue`**

## What the Blocked Pane Looks Like

```
  ❯ 1. Stop and wait for limit to reset
    2. Upgrade your plan
    3. Upgrade to Team plan

  Enter to confirm · Esc to cancel
```

## Steps Taken

1. **Capture the pane** to confirm state:
   ```bash
   tmux capture-pane -t ior:0.0 -p
   ```

2. **Create the resume script** at `~/.local/bin/ior-tmux-resume.sh`:
   ```bash
   #!/bin/bash
   set -euo pipefail

   TMUX_SOCKET="/tmp/tmux-$(id -u)/default"
   TARGET="ior:0.0"

   tmux -S "$TMUX_SOCKET" has-session -t "$TARGET" || {
       echo "Target pane $TARGET not found"; exit 1;
   }

   # Select option 1: "Stop and wait for limit to reset"
   tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" Enter

   # Wait 5 minutes past the advertised reset time
   sleep 300

   # Resume the Claude session
   tmux -S "$TMUX_SOCKET" send-keys -t "$TARGET" "continue" Enter
   ```

3. **Create the systemd user service** at `~/.config/systemd/user/ior-resume.service`:
   ```ini
   [Unit]
   Description=Resume Claude in ior tmux pane after rate-limit reset

   [Service]
   Type=oneshot
   ExecStart=/home/paul/.local/bin/ior-tmux-resume.sh
   Environment="PATH=/usr/local/bin:/usr/bin:/bin"
   ```

4. **Create the systemd user timer** at `~/.config/systemd/user/ior-resume.timer`:
   ```ini
   [Unit]
   Description=One-off timer for ior tmux resume at 13:10 today

   [Timer]
   OnCalendar=2026-06-11 13:10:00
   AccuracySec=1s
   Persistent=false

   [Install]
   WantedBy=timers.target
   ```

5. **Make executable and enable**:
   ```bash
   chmod +x ~/.local/bin/ior-tmux-resume.sh
   systemctl --user daemon-reload
   systemctl --user enable --now ior-resume.timer
   systemctl --user status ior-resume.timer
   ```

## Verification

Check timer state:
```bash
systemctl --user status ior-resume.timer
```

Expected output:
```
  Trigger: Thu 2026-06-11 13:10:00 EEST; 4h 3min left
  Triggers: ● ior-resume.service
```

## Key Details

| Item | Value |
|------|-------|
| Rate-limit reset time | Shown in the Claude banner (tz-aware) |
| TMUX socket | `/tmp/tmux-$(id -u)/default` |
| First keystroke | `Enter` confirms menu option 1 |
| Buffer sleep | `300` seconds (5 min) past reset time |
| Resume command | `continue` |
| Command suffix | `Enter` |

## Caveats

- The `continue` command is specific to Claude Code CLI; other agents use different resume verbs.
- If Claude changes its rate-limit UI (e.g., adds a countdown instead of a menu), update the first `send-keys` accordingly.
- `tmux send-keys` injects literal keystrokes; if the pane has scrolled or lost focus, the keys may land in the wrong place. Consider pinning the pane or using `tmux select-pane` first.
