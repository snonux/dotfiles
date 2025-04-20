set -gx EDITOR hx
set -gx VISUAL $EDITOR
set -gx GIT_EDITOR $EDITOR
set -gx HELIX_CONFIG_DIR $HOME/.config/helix
set -gx COPILOT_MODEL gpt-4o
set -gx HANDLER copilot

function editor::helix::theme::get_random
    echo not yet implemented
end

function editor::helix::theme::set
    set -l theme $argv[1]
    set -l config_file $HELIX_CONFIG_DIR/config.toml
    # sed "/^theme =/ { s/.*/theme = \"$theme\"/; }" $config_file >$config_file.tmp
    mv $config_file.tmp $config_file
end

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

if test -f $HELIX_CONFIG_DIR/config.toml
    # editor::helix::theme::set (editor::helix::theme::get_random)
end

abbr -a hxl 'editor::helix::open_with_lock'
abbr -a rhx 'editor::helix::edit::remote'
