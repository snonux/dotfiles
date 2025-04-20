set -gx EDITOR hx
set -gx VISUAL $EDITOR
set -gx GIT_EDITOR $EDITOR
set -gx HELIX_CONFIG_DIR $HOME/.config/helix
set -gx COPILOT_MODEL gpt-4o
set -gx HANDLER copilot

function editor::helix::open_with_lock
    set -l file $argv[1]
    set -l lock "$file.lock"
    if test -f "$lock"
        if pgrep -f hx
            echo "File lock $lock exists! Another instance is editing it?"
            return 2
        end
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

abbr -a hxl 'editor::helix::open_with_lock'
abbr -a rhx 'editor::helix::edit::remote'
