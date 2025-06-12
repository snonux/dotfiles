set -gx EDITOR hx
set -gx VISUAL $EDITOR
set -gx GIT_EDITOR $EDITOR
set -gx HELIX_CONFIG_DIR $HOME/.config/helix

function editor::helix::open_with_lock
    set -l file $argv[1]
    set -l lock "$file.lock"
    if test -f "$lock"
        echo "File lock $lock exists! Another instance is editing it?"
        return 2
    end
    touch $lock
    hx $file $argv[2..-1]
    rm $lock
end

function editor::helix::open_with_lock::force
    set -l file $argv[1]
    set -l lock "$file.lock"
    if test -f "$lock"
        echo "File lock $lock exists! Force deleting it and terminating all $EDITOR instances?"
        rm -f $lock
        pkill -f $EDITOR
    end
    touch $lock
    hx $file $argv[2..-1]
    rm $lock
end

function editor::helix::edit::remote
    set -l local_path $argv[1]
    set -l remote_uri $argv[2]
    scp $local_path $remote_uri; or return 1
    echo "LOCAL_PATH=$local_path; REMOTE_URI=$remote_uri" >~/.hx.remote.source
    hx $local_path
end

abbr -a lhx 'editor::helix::open_with_lock'
abbr -a hxl 'editor::helix::open_with_lock'
abbr -a hxlf 'editor::helix::open_with_lock::force'
abbr -a lhxf 'editor::helix::open_with_lock::force'
abbr -a rhx 'editor::helix::edit::remote'
abbr -a x hx
