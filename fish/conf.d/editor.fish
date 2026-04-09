set -gx EDITOR hx
set -gx VISUAL $EDITOR
set -gx GIT_EDITOR $EDITOR
set -gx HELIX_CONFIG_DIR $HOME/.config/helix

function editor::helix::lock_owner_pid
    set -l lock $argv[1]
    if not test -f "$lock"
        return 1
    end

    set -l pid (string trim -- (head -n 1 "$lock" 2>/dev/null))
    if not string match -rq '^[0-9]+$' -- "$pid"
        return 1
    end

    echo $pid
end

function editor::helix::lock_owner_is_active_fish
    set -l lock $argv[1]
    set -l pid (editor::helix::lock_owner_pid "$lock")
    if test $status -ne 0
        return 1
    end

    if not kill -0 $pid 2>/dev/null
        return 1
    end

    set -l command_name (string trim -- (ps -p $pid -o comm= 2>/dev/null))
    if not string match -rq '(^|/)fish$' -- "$command_name"
        return 1
    end

    return 0
end

function editor::helix::open_with_lock
    set -l file $argv[1]
    set -l lock "$file.lock"
    if test -f "$lock"
        if editor::helix::lock_owner_is_active_fish "$lock"
            set -l pid (editor::helix::lock_owner_pid "$lock")
            echo "File lock $lock exists and is owned by active fish shell PID $pid."
            return 2
        end

        echo "Removing stale or invalid file lock $lock."
        rm -f "$lock"
    end

    printf '%s\n' $fish_pid >"$lock"
    hx $file $argv[2..-1]
    set -l hx_status $status
    rm -f "$lock"
    return $hx_status
end

function editor::helix::open_with_lock::force
    set -l file $argv[1]
    set -l lock "$file.lock"
    set -l should_kill 0
    if test -f "$lock"
        if editor::helix::lock_owner_is_active_fish "$lock"
            set -l pid (editor::helix::lock_owner_pid "$lock")
            echo "File lock $lock exists and is owned by active fish shell PID $pid. Force deleting it and terminating all $EDITOR instances?"
            set should_kill 1
        else
            echo "Removing stale or invalid file lock $lock."
        end
        rm -f "$lock"
    end

    if test $should_kill -eq 1
        pkill -f $EDITOR
    end

    printf '%s\n' $fish_pid >"$lock"
    hx $file $argv[2..-1]
    set -l hx_status $status
    rm -f "$lock"
    return $hx_status
end

function editor::helix::edit::remote
    set -l local_path $argv[1]
    set -l remote_uri $argv[2]
    scp $local_path $remote_uri; or return 1
    echo "LOCAL_PATH=$local_path; REMOTE_URI=$remote_uri" >~/.hx.remote.source
    hx $local_path
end

function hxdiff
    set tmp (mktemp /tmp/hxdiff_XXXXXX.diff)
    diff -u -r $argv >$tmp
    hx $tmp
    rm -f $tmp

end

function tfdiff
    hxdiff --exclude=.claude --exclude=.cursor --exclude='tfplan' --exclude='*.tfplan' --exclude=modules.json --exclude=.terraform --exclude=.terraform.lock.hcl $argv
end

abbr -a lhx 'editor::helix::open_with_lock'
abbr -a hxl 'editor::helix::open_with_lock'
abbr -a hxlf 'editor::helix::open_with_lock::force'
abbr -a lhxf 'editor::helix::open_with_lock::force'
abbr -a rhx 'editor::helix::edit::remote'
abbr -a x hx
