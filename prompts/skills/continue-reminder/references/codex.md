# Codex CLI — Continue Reminder

Concrete example: Codex CLI running in a tmux pane hits a **model capacity
limit** and stalls with an inline error marker. Unlike Claude, there is no
reset-time menu; the stall can recur on every turn, so Codex is best served by
a **recurring watcher** rather than a one-shot delayed resume.

## Scenario (observed 2026-11-03)

- tmux session: `homelabfs` (window `0`, pane `0.0`, found dynamically)
- Error line: `■ Selected model is at capacity. Please try a different model.`
- Goal status line: `Goal stalled (/goal resume)` (can persist even while
  codex is working — do **not** use it for state detection)
- Idle input placeholder: `› Ask Codex to do anything`
- Busy indicator: `Working (… • esc to interrupt)` — note it renders above
  the input prompt line, not on the status bar
- Resume command: **`continue`** submitted as a normal user turn (`send-keys -l
  "continue"` then `Enter`)

## What the Blocked Pane Looks Like

```
■ Selected model is at capacity. Please try a different model.

• Completed `/root/controlled_guest_provider`

› Ask Codex to do anything
  GPT-6.1-Sol medium · ~/git/homelabfs · W… Goal stalled (/goal resume)
  ← for agents · ? for shortcuts
```

## State Detection (order matters)

1. Capture the visible screen plus a little scrollback
   (`capture-pane -p -S -60 -t <pane>`): the capacity error ends the turn,
   but wrap-up output (e.g. `• Completed …` lines) can push the message off
   the visible screen while codex stays stalled.
2. `esc to interrupt` visible → a turn is running → **never inject keys**.
   Codex can also sit *silently* for minutes retrying a capacity-limited
   model with no busy indicator, so also gate on the idle placeholder.
3. `Ask Codex to do anything` visible → idle at an empty input box → safe to
   submit `continue`.
4. A line exactly `› continue` visible without the idle placeholder → a
   `continue` is sitting **unsubmitted** in the input box (an `Enter` got
   swallowed) → press `Enter` alone; never retype over user text.

## Steps Taken (recurring capacity watcher)

1. **Find the pane dynamically** — codex panes are identified by
   `pane_current_command == codex` inside a named session, so pane
   renumbering does not break the watcher:
   ```bash
   tmux list-panes -t homelabfs -F '#{pane_id} #{pane_current_command}'
   ```

2. **Create the watcher script** at `~/.local/bin/codex-capacity-continue.sh`
   (implements the state detection above, sends `continue` + `Enter`, waits 2s,
   then sends a spare `Enter` — harmless no-op if the turn was already
   submitted, insurance if the first `Enter` was swallowed; keeps a per-pane
   state file with a 10-minute minimum between sends). Full working version
   lives on `earth` at that path — reuse it verbatim.

3. **Create the systemd user service** at
   `~/.config/systemd/user/codex-capacity-continue.service`:
   ```ini
   [Unit]
   Description=Resume codex in homelabfs tmux pane after capacity stall

   [Service]
   Type=oneshot
   ExecStart=%h/.local/bin/codex-capacity-continue.sh
   Environment="PATH=/usr/local/bin:/usr/bin:/bin"
   ```

4. **Create the recurring timer** at
   `~/.config/systemd/user/codex-capacity-continue.timer`
   (`OnCalendar=*:0/30` fires at :00 and :30 every hour, unlike the one-shot
   Claude `OnCalendar=<ISO_datetime>`):
   ```ini
   [Unit]
   Description=Recurring 30-min check for codex capacity stall in homelabfs tmux pane

   [Timer]
   OnCalendar=*:0/30
   AccuracySec=1s
   Persistent=false

   [Install]
   WantedBy=timers.target
   ```

5. **Enable and verify**:
   ```bash
   chmod +x ~/.local/bin/codex-capacity-continue.sh
   systemctl --user daemon-reload
   systemctl --user enable --now codex-capacity-continue.timer
   systemctl --user list-timers | grep codex
   journalctl --user -u codex-capacity-continue.service
   ```

6. **Run it once immediately** if the pane is already stalled:
   ```bash
   systemctl --user start codex-capacity-continue.service
   ```

## Verification

Watch the pane come back to life:
```bash
tmux capture-pane -p -t homelabfs:0.0
```
Expected after a successful resume: a `• Continuing …` response bullet and a
`Working (… • esc to interrupt)` indicator.

Service log evidence:
```bash
journalctl --user -u codex-capacity-continue.service --since today
```
Typical lines: `%0: capacity stall detected, sent 'continue'` and
`%0: Codex is working on a turn, skipping`.

## Key Details

| Item | Value |
|------|-------|
| TMUX socket | `/tmp/tmux-$(id -u)/default` |
| Pane targeting | `pane_current_command == codex`, optionally narrowed by `CODEX_PATH` (exact `pane_current_path`); `CODEX_SESSION=all` searches every session |
| Capacity marker | `Selected model is at capacity` |
| Busy gate | `esc to interrupt` visible → skip |
| Idle gate | `Ask Codex to do anything` placeholder visible |
| Resume command | `continue` (literal text) + `Enter`, spare `Enter` after 2s |
| Cadence | every 30 min (`OnCalendar=*:0/30`) |
| Resend guard | min 10 min between sends per pane (state file) |
| State dir | `~/.local/state/codex-continue/` |

## Caveats

- Multiple codex sessions can run at once (e.g. a `conf` session beside
  `homelabfs`); scope each watcher with `CODEX_SESSION`/`CODEX_PATH` in its
  service file. As of 2026-11-05 `earth` runs two units on the shared script:
  `codex-capacity-continue.service` (`CODEX_SESSION=all`,
  `CODEX_PATH=~/git/homelabfs`) and `codex-capacity-continue-conf.service`
  (`CODEX_SESSION=all`, `CODEX_PATH=~/git/conf`), each with a 30-min timer.
  Scoping by path with `CODEX_SESSION=all` survives session renames — the
  original session-scoped watcher silently stopped working when the
  `homelabfs` session was renamed to `player`.
- A user-paused goal (`Goal paused (/goal resume)`) never matches the capacity
  marker, so the watcher leaves it alone; only capacity stalls are resumed.
- The capacity error can recur on every turn; the 30-minute watcher retries
  automatically, and the resend guard prevents double-queueing.
- `send-keys` into a busy codex can queue a turn (backpressure); the
  `esc to interrupt` and idle-placeholder gates exist to prevent this.
- If the user has a draft typed in the input box (placeholder absent), do
  nothing — the script's final branch deliberately skips.
- Enable `loginctl enable-linger` so the user timer survives logout.