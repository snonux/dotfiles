# Modal Editor

Modal prompt editing for the Pi TUI.

This is the upstream `modal-editor.ts` example installed as a local extension in
your dotfiles-backed Pi tree. It replaces the default prompt editor with a
small Vim-like modal editor.

## What It Does

- starts in `INSERT` mode
- `Esc` switches to `NORMAL`
- `i` returns to `INSERT`
- `a` appends and returns to `INSERT`
- `h`, `j`, `k`, `l` move in `NORMAL`
- `0`, `$`, and `x` work in `NORMAL`

## Usage Flows

### Flow 1: Edit a prompt normally

1. Start Pi in a real terminal session.
2. Type in `INSERT` mode as usual.
3. Press `Esc` to switch to `NORMAL`.
4. Use `h`, `j`, `k`, `l` to move.
5. Press `i` to return to insert mode.

### Flow 2: Append instead of inserting

1. Press `Esc`.
2. Press `a`.
3. The cursor moves right and returns to `INSERT`.

### Flow 3: Abort agent work from normal mode

When Pi is already running an agent action, `Esc` in `NORMAL` passes through to
the app-level handling, so the usual abort behavior still works.

## Notes And Limits

- This only affects interactive Pi TUI sessions.
- It does not matter in one-shot `pi -p` mode.
- This is the stock upstream example, so it is intentionally more Vim-like than
  Helix-like. If you want the Helix-shaped editor you described earlier, this
  should be treated as the baseline install, not the final customization.
