function fish_user_key_bindings --description 'Custom bindings layered over the vi key bindings'
    # Workaround for the tmux 3.8 "escape glue":
    #
    # tmux 3.8's client holds the Escape key for up to 500 ms whenever a
    # terminal capability query is pending (window size, colors, theme,
    # clipboard, ...; GNOME Terminal/VTE answers several of them never or
    # late, so the window is open a lot: always for the first seconds after
    # every attach, after resizes and around theme reports). If the next
    # keypress arrives inside that window, tmux does not forward "Escape"
    # and "b" separately -- it merges them into a single Alt+b event and
    # writes "\eb" to the pane in one go.
    #
    # fish then runs the insert-mode Alt binding (alt-b = backward word)
    # and STAYS in insert mode: the first Esc+b seems to work (one word
    # back), but every following b is typed literally -- it looks like vi
    # mode quit after the first motion.
    #
    # Fix: in insert mode, bind the affected Alt keys to switch to normal
    # mode (-m default) AND run the same motion, so Esc+<motion> keeps
    # working no matter how tmux delivers the keys. When Esc arrives
    # normally (alone), nothing changes: these bindings never fire.
    #
    # Trade-off: a real Alt+<motion key> pressed in insert mode now enters
    # normal mode instead of only moving the cursor.
    if test "$fish_key_bindings" = fish_vi_key_bindings
        bind -M insert -m default \eb backward-word repaint-mode
        bind -M insert -m default \eB backward-bigword repaint-mode
        bind -M insert -m default \ew forward-word forward-single-char repaint-mode
        bind -M insert -m default \eW forward-bigword forward-single-char repaint-mode
        bind -M insert -m default \ee \
            'set fish_cursor_end_mode exclusive' \
            forward-single-char forward-word backward-char \
            'set fish_cursor_end_mode inclusive' repaint-mode
        bind -M insert -m default \eE \
            'set fish_cursor_end_mode exclusive' \
            forward-single-char forward-bigword backward-char \
            'set fish_cursor_end_mode inclusive' repaint-mode
        bind -M insert -m default \eh backward-char repaint-mode
        bind -M insert -m default \el forward-char repaint-mode
        bind -M insert -m default \ej down-or-search repaint-mode
        bind -M insert -m default \ek up-or-search repaint-mode
        bind -M insert -m default '\e$' end-of-line repaint-mode
        bind -M insert -m default '\e0' beginning-of-line repaint-mode
        bind -M insert -m default '\e^' beginning-of-line repaint-mode
        bind -M insert -m default \ex delete-char repaint-mode
    end
end
