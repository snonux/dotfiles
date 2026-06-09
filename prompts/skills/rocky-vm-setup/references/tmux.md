# Nested tmux on Rocky

Earth (outer tmux) uses the default **C-b** prefix. Rocky (inner tmux) uses **C-g** so you can control both layers.

## Visual distinction

| Layer | Prefix | Active Border | Status Bar | Pane Indicators |
|-------|--------|---------------|------------|-----------------|
| **Earth (outer)** | `C-b` | **Magenta** | White-on-purple | Default blue |
| **Rocky (inner)** | `C-g` | **Bright Red** | **Black-on-orange** (`colour208`) with `[ROCKY]` label | **Red/orange** pane numbers, border labels |

## Workflow

| Key | Action |
|-----|--------|
| `C-b c` | Create window in outer tmux (earth) |
| `C-g c` | Create window in inner tmux (rocky) |
| `C-b b` | Send `C-b` through to inner tmux |
| `C-g g` | Send `C-g` through to inner-inner tmux |

## Config

Rocky config is in `~/.config/tmux/tmux.rocky.conf` and sourced from `tmux.local.conf`:

```sh
# ~/.config/tmux/tmux.rocky.conf
unbind C-b
set -g prefix C-g
bind C-g send-prefix

# Drastic RED/ORANGE color scheme
set -g pane-active-border-style 'fg=brightred,bold'
set -g status-style             'bg=colour208,fg=black,bold'
set -g status-left              ' [ROCKY] #[bg=brightred,fg=white] #S '
set -g window-status-current-style 'bg=brightred,fg=white,bold'
set -g window-status-style         'bg=colour208,fg=black'

# Active pane indicators
set -g display-panes-colour       colour208       # prefix+q pane numbers
set -g display-panes-active-colour brightred       # active pane number
set -g pane-border-status         top              # show pane info on borders
set -g pane-border-format         '#[fg=colour208] #{pane_index} #[fg=brightred]#{pane_title} '
set -g window-status-current-format ' #I*#[bg=brightred,fg=white] #W '
```

## Important: source ordering

The rocky config must be sourced **at the end of** `~/.config/tmux/tmux.conf` so its color overrides win over the shared config. The `home_tmux_rocky` Rex task handles this by:

1. Cleaning any stale reference from `tmux.local.conf`
2. Appending `source-file ~/.config/tmux/tmux.rocky.conf` to the **end** of `tmux.conf`

## Terminal / color support

The inner tmux must advertise 256 colors (or helix/fzf/etc fall back to 16):

```sh
set -g default-terminal 'tmux-256color'
set -ga terminal-overrides ',xterm-256color:Tc,*-256color:Tc'
```

Without this, tmux defaults to `TERM=screen` (8 colors) and helix themes break.
