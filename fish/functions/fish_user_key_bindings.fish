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
    # Nested tmux makes it much worse: in a tmux client running inside a
    # tmux popup (prefix N/D/W/a/t), both clients hold Escape, and the
    # popup apparently never answers the inner client's queries. Measured:
    # Esc+key typed up to ~800 ms apart still arrives as one Alt+key, so
    # practically every Esc+key is glued there.
    #
    # fish then runs the insert-mode Alt binding instead of leaving insert
    # mode: Esc+b moves one word back but stays in insert mode, Esc+d
    # kills a word, Esc+v opens the editor, Esc+i does nothing, ...
    #
    # Fix: mirror every normal-mode binding into insert mode as an Alt
    # binding (see __fish_vi_esc_glue_bindings), so Esc+<anything> behaves
    # like vi no matter how tmux delivers the keys. When Esc arrives alone,
    # nothing changes: these bindings never fire.
    if test "$fish_key_bindings" = fish_vi_key_bindings
        __fish_vi_esc_glue_bindings
    end
end

function __fish_vi_esc_glue_bindings --description 'Mirror vi normal-mode bindings as insert-mode alt-<key> bindings'
    # For each normal-mode ("default") binding "[-m MODE] KEY[,MORE...] CMDS"
    # add
    #   bind -M insert alt-KEY[,MORE...] \
    #       __fish_vi_esc_glue_escape CMDS 'set fish_bind_mode MODE' repaint-mode
    # __fish_vi_esc_glue_escape first does what the swallowed Escape would
    # have done (switch to normal mode, step the cursor back one char).
    # MODE is the binding's own target mode (insert for i/a/A/cw/..., visual
    # for v, ...) or default. It is set explicitly instead of via `bind -m`
    # because `-m insert` on an insert-mode binding is a no-op and would
    # leave us in the normal mode the helper switched to. Multi-key
    # sequences work too: a glued Esc+d followed by w is alt-d,w.
    #
    # Generated from `bind` output instead of a hand-written list, so it
    # follows fish's preset and user normal-mode bindings automatically.
    #
    # Skipped first keys:
    # - modified keys (ctrl-x, alt-y, shift-tab, ...) and raw escape
    #   sequences: tmux never glues them into a plain alt-<key>;
    # - escape: Esc Esc is harmless (normal mode just cancels);
    # - enter: keeps Alt+Enter = "insert newline" usable.
    #
    # Trade-off: a real Alt+<key> pressed in insert mode now acts like
    # Esc+<key> (e.g. Alt+c no longer runs the fzf cd widget directly but
    # starts the vi "c" operator) -- the price for a working vi mode in
    # nested tmux.
    #
    # Two vectorised `string replace` calls instead of a per-line loop keep
    # the cost at ~10 ms per shell start (the loop took ~23 ms):
    # 1. normalise "bind [--preset] KEY CMDS" to "bind -m default KEY CMDS";
    # 2. rewrite "bind [--preset] -m MODE KEY CMDS" into the insert-mode
    #    bind; the negative lookahead drops the skipped first keys and -f
    #    drops every line that does not match.
    set -l lines (bind --preset -M default) (bind --user -M default)
    set lines (string replace -r -- '^bind (?:--preset )?(?!--preset |-m )' 'bind -m default ' $lines)
    string replace -rf -- '^bind (?:--preset )?-m (\S+) (?!(?:escape|enter|\\\\e[^,\s]*|[^,\s]+-[^,\s]+)[,\s])(\S+) (.*)$' \
        'bind -M insert alt-$2 __fish_vi_esc_glue_escape $3 \'set fish_bind_mode $1\' repaint-mode' $lines | source
end

function __fish_vi_esc_glue_escape --description 'Do what insert-mode Escape does, for a glued alt-<key>'
    # Same as the else-branch of fish's preset insert-mode escape binding:
    # enter normal mode and step back one char (vi puts the cursor ON the
    # last typed char), unless the cursor is at the start of a line. Without
    # this, Esc+x would delete nothing at the end of the line and Esc+a
    # would append one char too far right.
    set fish_bind_mode default
    if test (count (commandline --cut-at-cursor | tail -c2)) != 2
        commandline -f backward-char
    end
end
