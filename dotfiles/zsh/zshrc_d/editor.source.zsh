export EDITOR=hx
export VISUAL=$EDITOR
export GIT_EDITOR=$EDITOR
export HELIX_CONFIG_DIR=$HOME/.config/helix

# For https://github.com/leona/helix-gpt/blob/master/src/config.ts
# export OPENAI_MODEL=gpt-4o
# export OPENAI_MAX_TOKENS=14000
export COPILOT_MODEL=gpt-4o
export HANDLER=copilot 

editor::helix::theme::get_random () {
    for dir in $(hx --health \
        | awk '/^Runtime directories/ { print $3 }' | tr ';' ' '); do
        if [ -d $dir/themes ]; then
            ls $dir/themes
        fi
    done | grep -F .toml | sort -R | head -n 1 | cut -d. -f1
}

editor::helix::theme::set () {
    local -r theme="$1"; shift

    local -r config_file=$HELIX_CONFIG_DIR/config.toml

    sed "/^theme =/ { s/.*/theme = \"$theme\"/; }" \
        $config_file > $config_file.tmp && 
        mv $config_file.tmp $config_file
}

editor::helix::open_with_lock () {
    local -r file="$1"; shift
    local -r lock="$file.lock"

    if [ -f "$lock" ]; then
        if pgrep -f hx; then
            echo "File lock $lock exists! Another instance is editing it?"
            return 2
        fi
    fi

    touch $lock
    hx $file $@
    rm $lock
}
alias hxl=editor::helix::open_with_lock

editor::helix::edit::remote () {
    local -r local_path="$1"; shift
    local -r remote_uri="$1"; shift

    scp $local_path $remote_uri || return 1

    cat <<END >~/.hx.remote.source
LOCAL_PATH=$local_path
REMOTE_URI=$remote_uri
END
    hx $local_path
}
alias rhx=editor::helix::edit::remote

if [ -f $HELIX_CONFIG_DIR/config.toml ]; then
    editor::helix::theme::set $(editor::helix::theme::get_random)
fi

alias -s txt=$EDITOR
alias -s pp=$EDITOR
alias -s json=$EDITOR
alias -s xml=$EDITOR
alias -s erb=$EDITOR
alias -s c=$EDITOR
alias -s rb=$EDITOR
